"""
Operations sub-agent — fleet, pricing, suppliers, promotions, booking status.

Tools:  manage_fleet, manage_pricing_rules, manage_suppliers,
        manage_promotions, update_booking_status
Model:  CLOUD (role=admin → always CLOUD_PRIMARY)

Gating (PROJECT_CONTEXT §19 fix):
  - STATE-CHANGING actions (create/update/delete/toggle, update_booking_status) go
    through the confirmation gate — propose → user confirms → execute.
  - READ-ONLY actions (manage_fleet[list], manage_pricing_rules[get],
    manage_suppliers[list], manage_promotions[list]) are NOT gated. They execute
    immediately and the result is synthesised into prose (the same pattern
    insights_agent.py uses), so the admin actually SEES the data instead of a
    "Done — I've pulled up the list" one-liner that dropped it.

No key → node raises RuntimeError immediately (expected when GOOGLE_API_KEY unset).
"""
from __future__ import annotations

import sys, os, json

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import AIMessage, ToolMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from app.ai.agents.shared import (
    AgentState,
    format_tool_summary,
    resolve_proposal_state,
    run_with_confirmation,
    safe_tool_args,
    with_persona,
)
from app.ai.model_router import get_model
from app.ai.tool_registry import get_tools_for_role

_TOOLS = frozenset({
    "manage_fleet",
    "manage_pricing_rules",
    "manage_suppliers",
    "manage_promotions",
    "update_booking_status",
})

# Read-only action values per tool — these bypass the confirmation gate and are
# synthesised straight back to the admin. Everything else is state-changing.
_READ_ONLY = {
    "manage_fleet": frozenset({"list"}),
    "manage_pricing_rules": frozenset({"get"}),
    "manage_suppliers": frozenset({"list"}),
    "manage_promotions": frozenset({"list"}),
}


def _is_read_only(tool_name: str, action: str) -> bool:
    return action in _READ_ONLY.get(tool_name, frozenset())


async def operations_node(state: AgentState) -> dict:
    # get_model returns CLOUD_PRIMARY (None only if GOOGLE_API_KEY is missing).
    model = get_model()
    if model is None:
        raise RuntimeError("GOOGLE_API_KEY not set — add it to .env to use AVA")

    tools = [t for t in get_tools_for_role(state["role"], state["user_id"]) if t.name in _TOOLS]
    tool_map = {t.name: t for t in tools}
    model_with_tools = model.bind_tools(tools)

    # Mid-confirmation (user replied yes/no): let the shared gate finish it.
    # This branch makes no model call — it executes or cancels the pending action.
    if state.get("awaiting_confirmation") and state.get("pending_action"):
        return await run_with_confirmation(state, model_with_tools, tool_map)

    # New request — ask the model to pick a tool.
    messages = state["messages"]
    response = await model_with_tools.ainvoke(with_persona(messages))

    if not response.tool_calls:
        return {
            "messages": [response],
            "pending_action": None,
            "awaiting_confirmation": False,
        }

    tc = response.tool_calls[0]
    tool_name = tc["name"]
    action = str(tc["args"].get("action") or "").lower()

    # READ-ONLY: execute now and synthesise the data (no gate) — insights pattern.
    if _is_read_only(tool_name, action):
        tool_obj = tool_map.get(tool_name)
        if tool_obj is not None:
            result = await tool_obj.ainvoke(safe_tool_args(tool_obj, tc["args"]))
            tool_msg = ToolMessage(
                content=json.dumps(result, default=str),
                tool_call_id=tc["id"],
            )
            synthesis = await model.ainvoke(
                with_persona([*messages, response, tool_msg])
            )
            return {"messages": [response, tool_msg, synthesis]}

    # STATE-CHANGING: propose via the confirmation gate (same copy/flow as the
    # shared run_with_confirmation propose path, so writes are unchanged).
    tool_args = await resolve_proposal_state(tool_name, tc["args"])
    summary = format_tool_summary(tool_name, tool_args)
    return {
        "messages": [AIMessage(content=summary)],
        "pending_action": {"name": tool_name, "args": tool_args, "summary": summary},
        "awaiting_confirmation": True,
    }


def build_graph():
    g = StateGraph(AgentState)
    g.add_node("operations", operations_node)
    g.add_edge(START, "operations")
    g.add_edge("operations", END)
    return g.compile(checkpointer=MemorySaver())
