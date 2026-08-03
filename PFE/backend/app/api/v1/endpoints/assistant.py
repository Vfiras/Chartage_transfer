"""
POST /assistant/chat — supervisor-backed AI chat endpoint with SSE streaming.

Streaming level: node-level + periodic keep-alive, not token-by-token.
  The supervisor graph has five nodes (classify → gate → dispatch → safety →
  session_write).  Each node emits one SSE event when it completes.  During
  any node that takes longer than KEEPALIVE_INTERVAL seconds (the dispatch node
  calling the model is the main case), additional keep-alive token events
  are emitted every KEEPALIVE_INTERVAL seconds so the client connection stays
  alive and the UI can show a "thinking" indicator.

  True token-by-token streaming is NOT wired.  The sub-agents call the LLM
  via .ainvoke(), not .astream_events(), so individual tokens are never
  surfaced here.  Token streaming would require refactoring all six sub-agents.

SSE event schema:
  {"type": "token", "content": ""}       — node completed OR keep-alive tick
  {"type": "analytics", "content": {…}}  — business-analysis payload (charts,
                                           kpis, insights); emitted before done
  {"type": "done",  "content": "<text>"} — session_write fired; response ready
  {"type": "error", "content": "<msg>"}  — always the friendly _FRIENDLY_ERROR
                                           constant; raw errors are logged only

Keep-alive mechanism:
  The graph runs in a background asyncio task that pushes (kind, payload) tuples
  into a Queue.  The generator loop waits on that queue with a timeout of
  KEEPALIVE_INTERVAL seconds.  If no chunk arrives in time, a keep-alive token
  event is emitted and the loop retries.  This is safe: asyncio.wait_for timeout
  cancels the queue.get() coroutine but does NOT dequeue any item — the next
  get() call retrieves it correctly.

Thread isolation:
  thread_id from the request body is prefixed with the authenticated user_id.

Supervisor singleton:
  build_supervisor() is called once per process.  MemorySaver state persists
  across requests — required for the confirmation gate pattern.

domain intentionally omitted from per-request state_input:
  classify_intent_node's sticky confirmation check reads the prior domain from
  MemorySaver.  Resetting it to None would break "yes" after a confirmation.
"""
from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncGenerator
from typing import Any

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from langchain_core.messages import HumanMessage
from pydantic import BaseModel

from app.ai.agents.shared import extract_text
from app.ai.supervisor import build_supervisor
from app.core.deps import get_current_user

router = APIRouter()

KEEPALIVE_INTERVAL = 3.5  # seconds between keep-alive token events

# The ONLY error string ever sent to the client.  Any exception raised while the
# supervisor runs — quota (429/RESOURCE_EXHAUSTED), ChatGoogleGenerativeAIError,
# ClientError, connection failures, graph errors — is collapsed to this before
# it reaches the SSE stream.  Raw provider/API error text must never appear in
# the chat bubble; the real error is logged server-side only.
_FRIENDLY_ERROR = "AVA is temporarily unavailable. Please try again in a moment."

# Quota is a daily budget, not a blip — a distinct message stops the user
# retrying in a loop against a limit that will not clear until tomorrow.
_QUOTA_ERROR = (
    "AVA has reached today's request limit and will be back tomorrow. "
    "Everything else in the app works as normal."
)


# ---------------------------------------------------------------------------
# Supervisor singleton — one compiled graph per process
# ---------------------------------------------------------------------------

_supervisor = None


def _get_supervisor():
    global _supervisor
    if _supervisor is None:
        _supervisor = build_supervisor()
    return _supervisor


# ---------------------------------------------------------------------------
# Request schema
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    message: str
    thread_id: str


# ---------------------------------------------------------------------------
# SSE formatting helper
# ---------------------------------------------------------------------------

def _sse(type_: str, content: str) -> str:
    return f"data: {json.dumps({'type': type_, 'content': content})}\n\n"


def _sse_json(type_: str, content: dict) -> str:
    """SSE event whose content is a structured object (e.g. analytics charts)."""
    return f"data: {json.dumps({'type': type_, 'content': content}, default=str)}\n\n"


# ---------------------------------------------------------------------------
# Streaming generator with keep-alive
# ---------------------------------------------------------------------------

async def _stream_supervisor(
    message: str,
    user_id: str,
    role: str,
    thread_id: str,
) -> AsyncGenerator[str, None]:
    # Catch-all around the ENTIRE generator setup: if even building the
    # supervisor graph fails, the client still receives the friendly SSE error
    # event — never a raw 500 body or a Python traceback.
    try:
        supervisor = _get_supervisor()
    except Exception as exc:  # noqa: BLE001
        print(f"[assistant.chat] supervisor build failed; raw error: {exc!r}")
        yield _sse("error", _FRIENDLY_ERROR)
        return

    safe_thread = f"{user_id}:{thread_id}"
    config = {"configurable": {"thread_id": safe_thread}}
    state_input = {
        "messages": [HumanMessage(content=message)],
        "role": role,
        "user_id": user_id,
        "_access_denied": False,
        # domain intentionally absent — see module docstring
    }

    # Run the graph in a background task; push results into a queue so the
    # generator loop can interleave keep-alive events while waiting.
    queue: asyncio.Queue[tuple[str, Any]] = asyncio.Queue()

    async def _run() -> None:
        try:
            async for chunk in supervisor.astream(
                state_input, config=config, stream_mode="updates"
            ):
                await queue.put(("chunk", chunk))
        except Exception as exc:  # noqa: BLE001
            # Catch EVERYTHING (not just RuntimeError) — a Gemini
            # ChatGoogleGenerativeAIError/ClientError raised from a sub-agent's
            # direct .ainvoke() is not a RuntimeError and would otherwise leak
            # its raw dict into the stream.  Log the real cause, emit only the
            # friendly constant.
            print(f"[assistant.chat] supervisor failed; raw error: {exc!r}")
            # Quota exhaustion gets its own wording — it is not transient
            # within the day, so telling the user to retry "in a moment" is
            # actively misleading. Still a fixed constant; no provider detail.
            from app.ai.model_router import is_quota_error

            await queue.put(
                ("error", _QUOTA_ERROR if is_quota_error(exc) else _FRIENDLY_ERROR)
            )
        finally:
            await queue.put(("eof", None))

    task = asyncio.create_task(_run())

    try:
        while True:
            try:
                kind, payload = await asyncio.wait_for(
                    queue.get(), timeout=KEEPALIVE_INTERVAL
                )
            except asyncio.TimeoutError:
                # No chunk arrived — emit a keep-alive so the client knows
                # the server is still working (a dispatch/model call is running).
                yield _sse("token", "")
                continue

            if kind == "eof":
                break

            if kind == "error":
                # Only ever one of our own two constants — a raw provider
                # error can never reach the chat bubble.
                yield _sse(
                    "error",
                    payload if payload in (_FRIENDLY_ERROR, _QUOTA_ERROR)
                    else _FRIENDLY_ERROR,
                )
                break

            # kind == "chunk": one dict per completed graph node
            for node_name, update in payload.items():
                if node_name == "session_write":
                    ai_text = ""
                    for msg in reversed(update.get("messages", [])):
                        if hasattr(msg, "type") and msg.type == "ai":
                            ai_text = extract_text(msg)
                            break
                    # Analytics turns carry a chart/KPI payload — emit it as a
                    # dedicated "analytics" event BEFORE done, so the app
                    # renders the AnalyticsCard and then the narrative bubble.
                    analytics = update.get("_analytics_payload")
                    if analytics:
                        yield _sse_json("analytics", analytics)
                    yield _sse("done", ai_text)
                else:
                    # Node completed — emit a single token event
                    yield _sse("token", "")

    finally:
        task.cancel()


# ---------------------------------------------------------------------------
# Route
# ---------------------------------------------------------------------------

@router.post("/chat")
async def assistant_chat(
    payload: ChatRequest,
    current_user: dict = Depends(get_current_user),
) -> StreamingResponse:
    user_id = str(current_user["_id"])
    role = current_user.get("role", "client")

    return StreamingResponse(
        _stream_supervisor(payload.message, user_id, role, payload.thread_id),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx buffering for SSE
        },
    )
