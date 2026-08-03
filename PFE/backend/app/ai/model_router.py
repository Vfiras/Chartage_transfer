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
# Tier 2 — CLOUD_FALLBACK
#
# Gemini's free tier meters requests per DAY, per project, PER MODEL. A second
# model therefore carries its own independent budget: when the primary's daily
# allowance is spent, AVA keeps answering instead of failing outright.
# ---------------------------------------------------------------------------
CLOUD_FALLBACK: ChatGoogleGenerativeAI | None = None
if settings.google_api_key:
    CLOUD_FALLBACK = ChatGoogleGenerativeAI(
        model="gemini-flash-latest",
        google_api_key=settings.google_api_key,
        temperature=0,
    )


class _ResilientModel:
    """Primary model with automatic failover to the fallback tier.

    The sub-agents call ``get_model()`` and then ``.ainvoke()`` /
    ``.bind_tools()`` directly, so a fallback that only lived inside
    ``invoke_with_fallback`` never protected an actual chat turn. Returning this
    wrapper means every agent path gets failover with no changes in the agents.

    Only the two methods the agents use are proxied; anything else would be a
    silent behaviour change, so it is deliberately not forwarded.
    """

    def __init__(self, primary: Any, fallback: Any) -> None:
        self._primary = primary
        self._fallback = fallback

    def bind_tools(self, tools: Any, **kwargs: Any) -> "_ResilientModel":
        return _ResilientModel(
            self._primary.bind_tools(tools, **kwargs),
            self._fallback.bind_tools(tools, **kwargs) if self._fallback else None,
        )

    async def ainvoke(self, messages: Any, **kwargs: Any) -> Any:
        try:
            return await self._primary.ainvoke(messages, **kwargs)
        except Exception as exc:  # noqa: BLE001
            if self._fallback is None:
                raise
            print(f"[model_router] primary failed ({type(exc).__name__}); "
                  f"retrying on fallback model")
            try:
                return await self._fallback.ainvoke(messages, **kwargs)
            except Exception as exc2:  # noqa: BLE001
                # Surface the tier that actually ran out, not the first failure.
                if is_quota_error(exc) and is_quota_error(exc2):
                    raise QuotaExhaustedError(
                        "AVA has reached today's request limit."
                    ) from exc2
                raise


def get_model(task_type: str = "general", role: str = "client") -> Any:
    """Gemini with failover. None only when GOOGLE_API_KEY is unset."""
    if CLOUD_PRIMARY is None:
        return None
    return _ResilientModel(CLOUD_PRIMARY, CLOUD_FALLBACK)


async def invoke_with_fallback(
    messages: list,
    task_type: str = "general",
    role: str = "client",
) -> Any:
    """Invoke with the CLOUD_PRIMARY → CLOUD_FALLBACK chain.

    Raises RuntimeError immediately if CLOUD_PRIMARY is None (no API key).
    """
    model = get_model(task_type, role)

    if model is None:
        raise RuntimeError(
            "GOOGLE_API_KEY not set — add it to .env to use AVA"
        )

    try:
        # get_model() returns the resilient wrapper, so the tier walk (and its
        # logging) happens inside ainvoke — no second chain needed here.
        return await model.ainvoke(messages)
    except Exception as exc:  # noqa: BLE001
        # Every failure path — quota (429/RESOURCE_EXHAUSTED), connection
        # errors, ChatGoogleGenerativeAIError, ClientError, anything —
        # collapses to a user-safe message. The raw provider error is logged
        # server-side only and must never reach the SSE stream or chat bubble.
        print(
            f"[model_router] all tiers exhausted for task_type={task_type!r} "
            f"role={role!r}; raw error: {exc!r}"
        )
        # Quota exhaustion is worth distinguishing: it is not transient within
        # the day, so "try again in a moment" sends the user into a pointless
        # retry loop. No provider detail is exposed — only the category.
        if isinstance(exc, QuotaExhaustedError) or is_quota_error(exc):
            raise QuotaExhaustedError(
                "AVA has reached today's request limit and will be back "
                "tomorrow. All other features are unaffected."
            ) from exc
        raise RuntimeError(
            "AVA is temporarily unavailable. Please try again in a moment."
        ) from exc


class QuotaExhaustedError(RuntimeError):
    """The AI provider's request quota is spent — distinct from an outage."""


def is_quota_error(exc: Exception | None) -> bool:
    """True when a provider error is a rate-limit / quota rejection."""
    if exc is None:
        return False
    text = f"{exc!r}"
    return any(
        marker in text
        for marker in ("RESOURCE_EXHAUSTED", "429", "quota", "Quota",
                       "rate limit", "rate_limit")
    )


def _tier_name(model: Any) -> str:
    if model is CLOUD_PRIMARY:
        return "CLOUD_PRIMARY(gemini-2.5-flash)"
    if model is CLOUD_FALLBACK:
        return "CLOUD_FALLBACK(gemini-flash-latest)"
    return repr(model)
