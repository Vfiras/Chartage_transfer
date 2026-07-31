"""
Role-gated tool registry for the AVA agent.

get_tools_for_role(role, user_id) returns a list of LangChain tools ready to
hand to the LLM.  Identity is bound in here — the LLM-facing schema of every
returned tool contains only business parameters, never user_id or role.
"""
from __future__ import annotations

import sys, os
_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

import inspect
from datetime import datetime, timezone
from typing import get_type_hints

from pydantic import create_model
from langchain_core.tools import StructuredTool

from app.ai.tools_client import CLIENT_TOOLS
from app.ai.tools_admin import ADMIN_TOOLS
from app.core.database import get_database

# Tools that carry user_id in their signature and need it bound before LLM use
_NEEDS_USER_ID: frozenset[str] = frozenset({
    "get_trip_history",
    "create_booking",
    "update_booking",
    "cancel_booking",
    "recommend_vehicle",
    "get_user_promos",
    "submit_claim",
})


def _bind_user_id(tool_obj: StructuredTool, user_id: str) -> StructuredTool:
    """Return a new StructuredTool with user_id pre-filled and removed from the
    LLM-facing schema.

    Strategy: build a fresh Pydantic args_schema from the original function's
    type hints (minus user_id), then construct StructuredTool directly — this
    avoids from_function, which cannot introspect functools.partial under
    Python 3.12 / Pydantic v2.
    """
    original = tool_obj.coroutine

    # Resolve full type hints from the source function (handles Optional, etc.)
    try:
        hints = get_type_hints(original)
    except Exception:
        hints = {}

    sig = inspect.signature(original)
    fields: dict = {}
    for pname, param in sig.parameters.items():
        if pname == "user_id":
            continue
        ptype = hints.get(pname, str)
        default = param.default if param.default is not inspect.Parameter.empty else ...
        fields[pname] = (ptype, default)

    # Always create an explicit Pydantic model — even when fields={}.
    # Passing args_schema=None causes LangChain to fall back to introspecting the
    # StructuredTool.invoke method, which leaks RunnableConfig (with callbacks: array,
    # items: {}) and a bare args: array into the tool schema. Gemini enforces strict
    # JSON Schema and rejects array fields without a concrete "items" definition.
    ArgsSchema = create_model(f"_{tool_obj.name}_args", **fields)

    # Proper async wrapper — not a partial, so Python type machinery works
    async def bound_fn(**kwargs):
        return await original(user_id=user_id, **kwargs)

    return StructuredTool(
        name=tool_obj.name,
        description=tool_obj.description or "",
        coroutine=bound_fn,
        args_schema=ArgsSchema,
    )


_ADMIN_TOOL_NAMES: frozenset[str] = frozenset(t.name for t in ADMIN_TOOLS)


def _wrap_with_audit(tool_obj: StructuredTool, user_id: str, role: str) -> StructuredTool:
    """Wrap an admin StructuredTool to write an audit_log entry on every invocation.

    Logs: user_id, role, event='tool_call', tool_name, args, outcome, timestamp.
    The kwargs received here are already Pydantic-validated (filtered) by the time
    the coroutine is called, so they are the post-safe_tool_args values.
    """
    original_coroutine = tool_obj.coroutine

    async def audited_fn(**kwargs):
        db = get_database()
        now = datetime.now(timezone.utc)
        try:
            result = await original_coroutine(**kwargs)
            await db.audit_log.insert_one({
                "user_id": user_id,
                "role": role,
                "event": "tool_call",
                "tool_name": tool_obj.name,
                "args": {k: str(v) for k, v in kwargs.items()},
                "outcome": "success",
                "timestamp": now,
            })
            return result
        except Exception as exc:
            await db.audit_log.insert_one({
                "user_id": user_id,
                "role": role,
                "event": "tool_call",
                "tool_name": tool_obj.name,
                "args": {k: str(v) for k, v in kwargs.items()},
                "outcome": str(exc),
                "timestamp": now,
            })
            raise

    return StructuredTool(
        name=tool_obj.name,
        description=tool_obj.description or "",
        coroutine=audited_fn,
        args_schema=tool_obj.args_schema,
    )


def get_tools_for_role(role: str, user_id: str) -> list[StructuredTool]:
    """Return the appropriate tool list for the given role with user_id bound in.

    role == 'client'  →  8 client tools (user_id bound, not visible to LLM)
    role == 'admin'   →  8 client tools + 9 admin tools
    anything else     →  raises ValueError
    """
    if role not in ("client", "admin"):
        raise ValueError(f"Unknown role {role!r}. Must be 'client' or 'admin'.")

    bound_client_tools: list[StructuredTool] = []
    for t in CLIENT_TOOLS:
        if t.name in _NEEDS_USER_ID:
            bound_client_tools.append(_bind_user_id(t, user_id))
        else:
            bound_client_tools.append(t)

    if role == "client":
        return bound_client_tools

    # admin gets everything — admin tools wrapped with audit logging
    audited_admin = [_wrap_with_audit(t, user_id, "admin") for t in ADMIN_TOOLS]
    return bound_client_tools + audited_admin
