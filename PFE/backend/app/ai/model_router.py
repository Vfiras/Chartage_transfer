"""
AVA model router — two-tier LLM selection.

Tier priority:
  CLOUD_PRIMARY  ChatGoogleGenerativeAI(gemini-2.5-flash) — requires GOOGLE_API_KEY
  CLOUD_FALLBACK None                                     — no second provider configured

get_model(task_type, role) — always returns CLOUD_PRIMARY regardless of task or role.
invoke_with_fallback(messages, task_type, role) — tries CLOUD_PRIMARY, then CLOUD_FALLBACK.
  If CLOUD_PRIMARY is None (key missing), raises RuntimeError immediately.
"""
from __future__ import annotations

import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from typing import Any

from langchain_google_genai import ChatGoogleGenerativeAI

from app.core.config import settings

# ---------------------------------------------------------------------------
# Tier 1 — CLOUD_PRIMARY (gated on GOOGLE_API_KEY)
# ---------------------------------------------------------------------------
CLOUD_PRIMARY: ChatGoogleGenerativeAI | None = None
if settings.google_api_key:
    CLOUD_PRIMARY = ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",
        google_api_key=settings.google_api_key,
        temperature=0,
    )

# ---------------------------------------------------------------------------
# Tier 2 — CLOUD_FALLBACK (no second provider configured)
# ---------------------------------------------------------------------------
CLOUD_FALLBACK: None = None


def get_model(task_type: str = "general", role: str = "client") -> Any:
    """Always returns CLOUD_PRIMARY — routing is now flat, all requests go to Gemini."""
    return CLOUD_PRIMARY


async def invoke_with_fallback(
    messages: list,
    task_type: str = "general",
    role: str = "client",
) -> Any:
    """Invoke with CLOUD_PRIMARY → CLOUD_FALLBACK fallback chain.

    Raises RuntimeError immediately if CLOUD_PRIMARY is None (no API key).
    """
    preferred = get_model(task_type, role)

    if preferred is None:
        raise RuntimeError(
            "GOOGLE_API_KEY not set — add it to .env to use AVA"
        )

    chain: list[Any] = [preferred]
    if CLOUD_FALLBACK is not None:
        chain.append(CLOUD_FALLBACK)

    last_error: Exception | None = None
    for model in chain:
        try:
            return await model.ainvoke(messages)
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            print(f"[model_router] {_tier_name(model)} failed ({exc!r}); trying next tier...")

    # Every failure path — quota (429/RESOURCE_EXHAUSTED), connection errors,
    # ChatGoogleGenerativeAIError, ClientError, anything — collapses to ONE
    # user-safe message.  The raw provider error is logged server-side only and
    # must never reach the SSE stream or the chat bubble.
    print(
        f"[model_router] all tiers exhausted for task_type={task_type!r} "
        f"role={role!r}; raw error: {last_error!r}"
    )
    raise RuntimeError(
        "AVA is temporarily unavailable. Please try again in a moment."
    )


def _tier_name(model: Any) -> str:
    if model is CLOUD_PRIMARY:
        return "CLOUD_PRIMARY(gemini-2.5-flash)"
    return repr(model)
