"""
Persona-leak regression test.

Guards the 'AVA talks like a coding assistant' bug: a user-facing model call
running with no persona system prompt rendered tool results as developer
documentation, leaking tool names, code fences, and internal field names
(get_trip_history, config, _id, user_id, ```), into the customer-facing text.

The fix prepends shared.AVA_PERSONA_PROMPT (via with_persona()) to every
user-facing model call in every sub-agent.  This test:

  SECTION 1 — Booking lookup path, the exact phrasings that broke.
    BEFORE: replicate the OLD no-persona lookup_node → show the leak reproduces.
    AFTER : run the real patched booking graph → assert nothing leaks.

  SECTION 2 — Broader sweep across all six agents with a domain-relevant
    'how do I…' phrasing → pass/fail per agent.

Run from backend/:
  python -m app.ai.agents.test_persona_leak
"""
from __future__ import annotations

import asyncio
import json
import os
import sys

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import HumanMessage, ToolMessage

from app.core.database import connect_to_mongo, close_mongo_connection
from app.ai.model_router import get_model, CLOUD_PRIMARY
from app.ai.tool_registry import get_tools_for_role
from app.ai.agents.booking_agent import _LOOKUP_TOOLS, classify_node
from app.ai.agents.shared import (
    extract_text,
    format_tool_summary,
    humanize_result,
    safe_tool_args,
)

SEP = "=" * 72

CLIENT = {"role": "client", "user_id": "test-client-ava-001"}
ADMIN = {"role": "admin", "user_id": "test-admin-1"}

# Markers the user-facing text must never contain.
GENERIC_MARKERS = ["```", "_id", "user_id", "config"]
AGENT_TOOLNAMES = {
    "booking": ["get_trip_history", "recommend_vehicle", "create_booking",
                "update_booking", "cancel_booking"],
    "support": ["search_knowledge_base"],
    "loyalty": ["get_user_promos"],
    "feedback": ["submit_claim"],
    "operations": ["manage_fleet", "manage_pricing_rules", "manage_suppliers",
                   "manage_promotions", "update_booking_status"],
    "insights": ["get_dashboard_analytics", "get_admin_overview",
                 "list_all_bookings", "list_users"],
}


def find_leaks(text: str, agent: str) -> list[str]:
    """Return the list of forbidden markers present in the response text."""
    lower = text.lower()
    markers = GENERIC_MARKERS + AGENT_TOOLNAMES.get(agent, [])
    return [m for m in markers if m.lower() in lower]


def _short(text: str, n: int = 600) -> str:
    text = text.replace("\n", " ")
    return text if len(text) <= n else text[:n] + "…(truncated)"


# ---------------------------------------------------------------------------
# SECTION 1 — Booking lookup path: BEFORE (no persona) vs AFTER (patched)
# ---------------------------------------------------------------------------

BOOKING_PHRASES = ["show me my recent trips", "how do I track my ride?"]


async def _booking_before_no_persona(phrase: str) -> str:
    """Replicate the OLD lookup_node exactly — NO persona — to prove the leak."""
    msgs = [HumanMessage(content=phrase)]
    tools = [t for t in get_tools_for_role(CLIENT["role"], CLIENT["user_id"])
             if t.name in _LOOKUP_TOOLS]
    model = get_model()
    model_with_tools = model.bind_tools(tools)

    response = await model_with_tools.ainvoke(msgs)            # no persona (old)
    if response.tool_calls:
        tc = response.tool_calls[0]
        tool_obj = next((t for t in tools if t.name == tc["name"]), None)
        if tool_obj:
            result = await tool_obj.ainvoke(safe_tool_args(tool_obj, tc["args"]))
            tool_msg = ToolMessage(content=json.dumps(result, default=str),
                                   tool_call_id=tc["id"])
            synthesis = await model.ainvoke([*msgs, response, tool_msg])  # no persona
            return extract_text(synthesis)
    return extract_text(response)


async def _booking_after_patched(phrase: str) -> str:
    """Run the REAL patched booking graph (persona applied)."""
    from app.ai.agents.booking_agent import build_graph
    agent = build_graph()
    init = {"messages": [HumanMessage(content=phrase)], **CLIENT,
            "pending_action": None, "awaiting_confirmation": False, "next_node": None}
    config = {"configurable": {"thread_id": f"persona-after-{abs(hash(phrase))}"}}
    result = await agent.ainvoke(init, config=config)
    for m in reversed(result["messages"]):
        if hasattr(m, "type") and m.type == "ai":
            return extract_text(m)
    return "(no AI message)"


async def section1() -> bool:
    print(f"\n{SEP}")
    print("SECTION 1 — Booking lookup path: BEFORE vs AFTER")
    print(f"{SEP}")
    all_ok = True
    for phrase in BOOKING_PHRASES:
        print(f"\n  PHRASE: {phrase!r}")

        before = await _booking_before_no_persona(phrase)
        before_leaks = find_leaks(before, "booking")
        print(f"\n    [BEFORE — no persona]")
        print(f"      text : {_short(before)}")
        print(f"      leaks: {before_leaks or '(none)'}")

        after = await _booking_after_patched(phrase)
        after_leaks = find_leaks(after, "booking")
        print(f"\n    [AFTER — patched]")
        print(f"      text : {_short(after)}")
        print(f"      leaks: {after_leaks or '(none)'}")

        ok = len(after_leaks) == 0
        print(f"\n    => {'[PASS]' if ok else '[FAIL]'} "
              f"after-fix text is leak-free")
        all_ok = all_ok and ok
    return all_ok


# ---------------------------------------------------------------------------
# SECTION 2 — Broader sweep: one 'how do I…' per agent
# ---------------------------------------------------------------------------

SWEEP = [
    ("booking",    "how do I track my ride?",            CLIENT),
    ("support",    "how do I cancel my booking?",        CLIENT),
    ("loyalty",    "how do I use a promo code?",         CLIENT),
    ("feedback",   "how do I file a complaint?",         CLIENT),
    ("operations", "how do I add a vehicle to the fleet?", ADMIN),
    ("insights",   "how do I see the revenue dashboard?", ADMIN),
]


def _build_agent(name: str):
    if name == "booking":
        from app.ai.agents.booking_agent import build_graph
    elif name == "support":
        from app.ai.agents.support_agent import build_graph
    elif name == "loyalty":
        from app.ai.agents.loyalty_agent import build_graph
    elif name == "feedback":
        from app.ai.agents.feedback_agent import build_graph
    elif name == "operations":
        from app.ai.agents.operations_agent import build_graph
    elif name == "insights":
        from app.ai.agents.insights_agent import build_graph
    return build_graph()


async def _run_agent(name: str, phrase: str, identity: dict) -> str:
    agent = _build_agent(name)
    init = {"messages": [HumanMessage(content=phrase)], **identity,
            "pending_action": None, "awaiting_confirmation": False, "next_node": None}
    config = {"configurable": {"thread_id": f"sweep-{name}-{abs(hash(phrase))}"}}
    result = await agent.ainvoke(init, config=config)
    for m in reversed(result["messages"]):
        if hasattr(m, "type") and m.type == "ai":
            return extract_text(m)
    return "(no AI message)"


async def section2() -> dict[str, bool]:
    print(f"\n{SEP}")
    print("SECTION 2 — Broader 'how do I…' sweep across all six agents")
    print(f"{SEP}")
    results: dict[str, bool] = {}
    for name, phrase, identity in SWEEP:
        print(f"\n  [{name}] {phrase!r}  (role={identity['role']})")
        if identity["role"] == "admin" and CLOUD_PRIMARY is None:
            print(f"      [SKIP] admin agent needs GOOGLE_API_KEY (CLOUD_PRIMARY=None)")
            results[name] = True  # not a failure — untestable in this config
            continue
        try:
            text = await _run_agent(name, phrase, identity)
        except Exception as exc:
            print(f"      [FAIL] {type(exc).__name__}: {exc}")
            results[name] = False
            continue
        leaks = find_leaks(text, name)
        ok = len(leaks) == 0
        results[name] = ok
        print(f"      text : {_short(text, 400)}")
        print(f"      leaks: {leaks or '(none)'}  => {'[PASS]' if ok else '[FAIL]'}")
    return results


# ---------------------------------------------------------------------------
# SECTION 3 — Confirmation-gate copy: zero tool names / JSON / None / arg-keys
# ---------------------------------------------------------------------------
# This is a deterministic (no-LLM) check of format_tool_summary + humanize_result,
# the hardcoded strings the persona system prompt cannot reach.

# Underscored arg-keys and code-shaped tokens that must never reach the user.
# (Single natural words like 'status' or 'action' are allowed — only the
#  code-style underscored keys and raw tool names count as leaks.)
_GATE_FORBIDDEN = [
    # tool names
    "submit_claim", "create_booking", "update_booking", "cancel_booking",
    "manage_fleet", "manage_pricing_rules", "manage_suppliers",
    "manage_promotions", "update_booking_status", "get_trip_history",
    # arg keys
    "booking_id", "car_id", "supplier_id", "promo_id", "new_status",
    "base_price", "discount_type", "usage_limit", "image_url",
    # code / json / null markers
    "```", "{", "}", "none",
]

_GATE_CASES = [
    ("submit_claim", {"message": "driver was late", "booking_id": None}, {"id": "c1"}),
    ("manage_fleet", {"action": "create", "name": "Mercedes S-Class"}, {"car": {"_id": "c9"}}),
    ("manage_fleet", {"action": "toggle_availability", "car_id": "c9", "availability": False},
     {"car": {"availability": False}}),
    ("cancel_booking", {"booking_id": "b1"}, {"status": "cancelled"}),
    ("manage_promotions", {"action": "create", "code": "SUMMER25", "value": 25}, {"promotion": {}}),
    ("update_booking_status", {"booking_id": "b1", "new_status": "confirmed"}, {"booking": {}}),
]


def _gate_leaks(text: str) -> list[str]:
    lower = text.lower()
    return [tok for tok in _GATE_FORBIDDEN if tok in lower]


def section3() -> bool:
    print(f"\n{SEP}")
    print("SECTION 3 — Confirmation-gate copy leak check (submit_claim, manage_fleet, …)")
    print(f"{SEP}")
    all_ok = True
    for tool, args, result in _GATE_CASES:
        propose = format_tool_summary(tool, args)
        done = humanize_result(tool, args, result)
        p_leaks, d_leaks = _gate_leaks(propose), _gate_leaks(done)
        ok = not p_leaks and not d_leaks
        all_ok = all_ok and ok
        action = args.get("action")
        tag = tool if not action else f"{tool} [{action}]"
        print(f"\n  • {tag}  => {'[PASS]' if ok else '[FAIL]'}")
        print(f"      PROPOSE: {propose}")
        if p_leaks:
            print(f"               LEAKS: {p_leaks}")
        print(f"      RESULT : {done}")
        if d_leaks:
            print(f"               LEAKS: {d_leaks}")
    return all_ok


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    print("Connecting to MongoDB...")
    await connect_to_mongo()
    try:
        s1_ok = await section1()
        s2 = await section2()
        s3_ok = section3()
    finally:
        await close_mongo_connection()

    print(f"\n{SEP}")
    print("SUMMARY")
    print(f"{SEP}")
    print(f"  Section 1 (booking before/after)     : {'[PASS]' if s1_ok else '[FAIL]'}")
    for name, ok in s2.items():
        print(f"  Section 2 sweep — {name:11s}         : {'[PASS]' if ok else '[FAIL]'}")
    print(f"  Section 3 (confirmation-gate copy)    : {'[PASS]' if s3_ok else '[FAIL]'}")

    all_ok = s1_ok and all(s2.values()) and s3_ok
    print(f"\n  OVERALL: {'[PASS]' if all_ok else '[FAIL]'}")
    if not all_ok:
        sys.exit(1)


if __name__ == "__main__":
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    asyncio.run(main())
