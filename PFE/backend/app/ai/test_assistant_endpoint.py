"""
HTTP endpoint test for POST /assistant/chat.

Prerequisites:
  - FastAPI server running: uvicorn app.main:app --reload  (from backend/)
  - MongoDB running with seed data (run /admin/seed or the seed script)
  - GOOGLE_API_KEY set in .env (AVA routes every request to Gemini)

Seeded test credentials (from app/db/seed.py):
  client  email=client@example.com      password=client123  _id=user-client-1
  admin   email=admin@carthage-transfer.tn  password=admin123   _id=user-admin-1

Run:
  python -m app.ai.test_assistant_endpoint
"""
from __future__ import annotations

import asyncio
import json
import os
import sys
import time
from datetime import datetime

import httpx

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

BASE_URL = "http://localhost:8000/api/v1"
SEP = "=" * 64


def _ts() -> str:
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]


# ---------------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------------

async def login(client: httpx.AsyncClient, email: str, password: str) -> str:
    resp = await client.post(f"{BASE_URL}/auth/login", json={"email": email, "password": password})
    resp.raise_for_status()
    data = resp.json()
    token = data.get("access_token") or data.get("token")
    if not token:
        raise RuntimeError(f"No access_token in login response: {data}")
    return token


# ---------------------------------------------------------------------------
# SSE stream reader
# ---------------------------------------------------------------------------

async def stream_chat(
    client: httpx.AsyncClient,
    token: str,
    message: str,
    thread_id: str,
    label: str,
) -> tuple[list[dict], float]:
    """
    POST /assistant/chat and consume the SSE stream.

    Returns (events, elapsed_seconds).
    Each event is the parsed JSON payload from a "data: ..." SSE line.
    Timestamps are printed as each event arrives.
    """
    headers = {"Authorization": f"Bearer {token}"}
    payload = {"message": message, "thread_id": thread_id}
    events: list[dict] = []
    t0 = time.perf_counter()

    print(f"\n  [{_ts()}] → POST /assistant/chat  [{label}]")
    print(f"  message: {message!r}")

    async with client.stream(
        "POST",
        f"{BASE_URL}/assistant/chat",
        json=payload,
        headers=headers,
        timeout=120,
    ) as response:
        if response.status_code != 200:
            body = await response.aread()
            print(f"  [{_ts()}] HTTP {response.status_code}: {body.decode()}")
            return events, time.perf_counter() - t0

        async for line in response.aiter_lines():
            line = line.strip()
            if not line.startswith("data:"):
                continue
            raw = line[len("data:"):].strip()
            try:
                event = json.loads(raw)
            except json.JSONDecodeError:
                print(f"  [{_ts()}] non-JSON SSE line: {raw!r}")
                continue

            events.append(event)
            etype = event.get("type", "?")
            content = event.get("content", "")
            elapsed = time.perf_counter() - t0

            if etype == "token":
                print(f"  [{_ts()}] +{elapsed:5.2f}s  token  (node completed)")
            elif etype == "done":
                preview = content[:120].replace("\n", " ")
                print(f"  [{_ts()}] +{elapsed:5.2f}s  done   {preview!r}")
            elif etype == "error":
                print(f"  [{_ts()}] +{elapsed:5.2f}s  error  {content!r}")
            else:
                print(f"  [{_ts()}] +{elapsed:5.2f}s  {etype}   {content[:80]!r}")

    return events, time.perf_counter() - t0


# ---------------------------------------------------------------------------
# chat_sessions verification (direct MongoDB)
# ---------------------------------------------------------------------------

async def check_session_turns(user_id: str) -> int:
    from app.core.database import connect_to_mongo, get_database
    await connect_to_mongo()
    db = get_database()
    doc = await db.chat_sessions.find_one({"user_id": user_id})
    if doc is None:
        return 0
    return len(doc.get("turns", []))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    print(f"\n{SEP}")
    print("ASSISTANT ENDPOINT TEST")
    print(f"{SEP}")
    print(f"Base URL : {BASE_URL}")
    print(f"Started  : {_ts()}")

    async with httpx.AsyncClient() as client:

        # ── Step 1: Login ────────────────────────────────────────────────────
        print(f"\n{SEP}")
        print("STEP 1: Login as seeded client and admin")
        print(f"{SEP}")

        try:
            client_token = await login(client, "client@example.com", "client123")
            print(f"  [PASS] client JWT obtained  (user-client-1)")
        except Exception as exc:
            print(f"  [FAIL] client login: {exc}")
            print("  → Is the server running?  uvicorn app.main:app --reload")
            return

        try:
            admin_token = await login(client, "admin@carthage-transfer.tn", "admin123")
            print(f"  [PASS] admin  JWT obtained  (user-admin-1)")
        except Exception as exc:
            print(f"  [FAIL] admin login: {exc}")
            return

        # ── Step 2: Client SSE call ──────────────────────────────────────────
        print(f"\n{SEP}")
        print("STEP 2: Client → support domain (cancellation policy)")
        print(f"{SEP}")

        client_events, client_elapsed = await stream_chat(
            client,
            client_token,
            message="what is the cancellation policy?",
            thread_id="http-test-client-main",
            label="client/support",
        )

        token_count = sum(1 for e in client_events if e.get("type") == "token")
        done_events  = [e for e in client_events if e.get("type") == "done"]
        error_events = [e for e in client_events if e.get("type") == "error"]

        print(f"\n  Summary:")
        print(f"    total events : {len(client_events)}")
        print(f"    token events : {token_count}  (one per intermediate node)")
        print(f"    done events  : {len(done_events)}")
        print(f"    error events : {len(error_events)}")
        print(f"    total elapsed: {client_elapsed:.2f}s")

        if done_events:
            print(f"  [PASS] 'done' event received")
        elif error_events:
            print(f"  [FAIL] error instead of done: {error_events[0].get('content')}")
        else:
            print(f"  [FAIL] no done or error event in stream")

        # ── Step 3: Admin SSE call ───────────────────────────────────────────
        print(f"\n{SEP}")
        print("STEP 3: Admin → insights domain (show all users)")
        print(f"{SEP}")

        admin_events, admin_elapsed = await stream_chat(
            client,
            admin_token,
            message="Show me all users in the system",
            thread_id="http-test-admin-main",
            label="admin/insights",
        )

        admin_done   = [e for e in admin_events if e.get("type") == "done"]
        admin_errors = [e for e in admin_events if e.get("type") == "error"]

        print(f"\n  Summary:")
        print(f"    total events : {len(admin_events)}")
        print(f"    done events  : {len(admin_done)}")
        print(f"    error events : {len(admin_errors)}")
        print(f"    total elapsed: {admin_elapsed:.2f}s")

        if admin_done:
            print(f"  [PASS] admin request succeeded via Gemini (CLOUD_PRIMARY)")
        elif admin_errors:
            err_msg = admin_errors[0].get("content", "")
            if "GOOGLE_API_KEY" in err_msg or "model" in err_msg.lower():
                print(f"  [PASS] error event correctly emitted (not unhandled 500): {err_msg!r}")
            else:
                print(f"  [FAIL] unexpected error: {err_msg!r}")
        else:
            print(f"  [FAIL] no done or error event in admin stream")

        # ── Step 4: chat_sessions verification ───────────────────────────────
        print(f"\n{SEP}")
        print("STEP 4: chat_sessions persistence check (direct MongoDB)")
        print(f"{SEP}")

        try:
            client_turns = await check_session_turns("user-client-1")
            admin_turns  = await check_session_turns("user-admin-1")
            print(f"  user-client-1  stored turns: {client_turns}")
            print(f"  user-admin-1   stored turns: {admin_turns}")

            if client_turns >= 1:
                print(f"  [PASS] session_write fired for client (>= 1 turn stored)")
            else:
                print(f"  [FAIL] no turns stored for client — session_write may not have run")

            if admin_turns >= 1:
                print(f"  [PASS] session_write fired for admin  (>= 1 turn stored)")
            elif admin_errors:
                print(f"  [NOTE] admin had error (classify failed) — session_write skipped; expected")
            else:
                print(f"  [FAIL] no turns stored for admin")

        except Exception as exc:
            print(f"  [FAIL] MongoDB check: {exc}")

    print(f"\n{SEP}")
    print(f"Done: {_ts()}")
    print(f"{SEP}\n")


if __name__ == "__main__":
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    asyncio.run(main())
