"""
Loyalty sub-agent — surfaces promo codes, points balance, and tier status.

Tool:  get_user_promos
Model: Gemini (CLOUD_PRIMARY)
Gate:  none — read-only
"""
from __future__ import annotations

import sys, os, json

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import AIMessage, ToolMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from app.ai.agents.shared import AgentState, safe_tool_args, with_persona
from app.ai.model_router import get_model
from app.ai.tool_registry import get_tools_for_role

_TOOLS = frozenset({"get_user_promos"})


def _format_promos(promos: list) -> str:
    """Render active promo codes from the precomputed fields — no model, no leak."""
    if not promos:
        return "You don't have any active promo codes right now."
    lines = ["You have these active promo codes:"]
    for p in promos:
        code = (p.get("code") or "").strip()
        val = p.get("value")
        dtype = p.get("discount_type", "percentage")
        if val is not None:
            disc = f"{val:g}% off" if dtype == "percentage" else f"{val:g} off"
            lines.append(f"  • {code} — {disc}" if code else f"  • {disc}")
        elif code:
            lines.append(f"  • {code}")
    return "\n".join(lines)


def _loyalty_template(result: dict) -> str:
    """Deterministic loyalty reply built straight from get_user_promos' precomputed
    fields.  Used ONLY as the cloud-failure fallback so a quota/outage still yields
    an exact, correct answer.  Covers normal-tier (exact points/trips gap) and
    top-tier (highest tier, no further requirement).
    """
    res = result or {}
    points = res.get("points", 0)
    tier = res.get("tier", "Bronze")
    next_tier = res.get("next_tier")
    pts_gap = res.get("points_to_next_tier", 0)
    trips_gap = res.get("trips_to_next_tier", 0)

    if next_tier:  # normal tier — state the exact, precomputed gap
        head = (
            f"You're currently a {tier}-tier member with {points} points. "
            f"You need {pts_gap} more points "
            f"({trips_gap} more completed {'trip' if trips_gap == 1 else 'trips'}) "
            f"to reach {next_tier}."
        )
    else:  # top tier — no further requirement
        head = (
            f"You're currently a {tier}-tier member with {points} points — "
            f"that's our highest tier, so there's no further requirement."
        )

    return f"{head}\n\n{_format_promos(res.get('available_promos') or [])}"


async def loyalty_node(state: AgentState) -> dict:
    tools = [t for t in get_tools_for_role(state["role"], state["user_id"]) if t.name in _TOOLS]
    model = get_model()
    model_with_tools = model.bind_tools(tools)
    messages = state["messages"]

    response = await model_with_tools.ainvoke(with_persona(messages))

    if response.tool_calls:
        tc = response.tool_calls[0]
        tool_obj = next((t for t in tools if t.name == tc["name"]), None)
        if tool_obj:
            result = await tool_obj.ainvoke(safe_tool_args(tool_obj, tc["args"]))
            tool_msg = ToolMessage(
                content=json.dumps(result, default=str),
                tool_call_id=tc["id"],
            )
            synth_input = with_persona([*messages, response, tool_msg])

            # On cloud failure, fall back to the DETERMINISTIC template built from
            # the precomputed fields — guarantees an exact tier-gap answer even
            # when Gemini is unavailable (quota/outage).
            synth_model = get_model()
            try:
                if synth_model is None:
                    raise RuntimeError("no cloud synthesis tier configured")
                synthesis = await synth_model.ainvoke(synth_input)
                return {"messages": [response, tool_msg, synthesis]}
            except Exception as exc:  # noqa: BLE001
                print(f"[loyalty] cloud synthesis failed ({exc!r}); using deterministic template")
                if tc["name"] == "get_user_promos":
                    return {"messages": [response, tool_msg,
                                         AIMessage(content=_loyalty_template(result))]}
                raise

    return {"messages": [response]}


def build_graph():
    g = StateGraph(AgentState)
    g.add_node("loyalty", loyalty_node)
    g.add_edge(START, "loyalty")
    g.add_edge("loyalty", END)
    return g.compile(checkpointer=MemorySaver())
