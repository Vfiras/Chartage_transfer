"""
Feedback sub-agent — collects complaint/feedback and submits via submit_claim.

Tool:  submit_claim
Model: Gemini (CLOUD_PRIMARY)
Gate:  YES — submit_claim writes to DB, so confirmation is required.
"""
from __future__ import annotations

import sys, os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from app.ai.agents.shared import AgentState, run_with_confirmation
from app.ai.model_router import get_model
from app.ai.tool_registry import get_tools_for_role

_TOOLS = frozenset({"submit_claim"})


async def feedback_node(state: AgentState) -> dict:
    tools = [t for t in get_tools_for_role(state["role"], state["user_id"]) if t.name in _TOOLS]
    tool_map = {t.name: t for t in tools}
    model = get_model()
    model_with_tools = model.bind_tools(tools)
    return await run_with_confirmation(state, model_with_tools, tool_map)


def build_graph():
    g = StateGraph(AgentState)
    g.add_node("feedback", feedback_node)
    g.add_edge(START, "feedback")
    g.add_edge("feedback", END)
    return g.compile(checkpointer=MemorySaver())
