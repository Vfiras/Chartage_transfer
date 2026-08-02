"""
Insights sub-agent — read-only admin analytics and reporting.

Tools:  get_dashboard_analytics, get_admin_overview, list_all_bookings,
        list_users, run_business_analysis
Model:  Gemini (CLOUD_PRIMARY)
Gate:   none — read-only.

Business-analysis fast path: when the message matches an analysis trigger
("full business review", "pricing impact", …) the node calls
run_business_analysis DIRECTLY with the detected analysis_type — deterministic
routing, one fewer model call — and attaches the chart/KPI payload to the
AIMessage (additional_kwargs["analytics"]) for the SSE layer to stream to the
app, where it renders as an interactive AnalyticsCard.
"""
from __future__ import annotations

import sys, os, json
from uuid import uuid4

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import AIMessage, ToolMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from app.ai.agents.shared import AgentState, _last_human_text, safe_tool_args, with_persona
from app.ai.analysis_triggers import detect_analysis_mode
from app.ai.model_router import get_model
from app.ai.tool_registry import get_tools_for_role

_TOOLS = frozenset({
    "get_dashboard_analytics",
    "get_admin_overview",
    "list_all_bookings",
    "list_users",
    "run_business_analysis",
})

_WINDOW_MONTHS = {
    "full_review": 12,
    "seasonal": 12,
    "pricing": 12,
    "revenue": 6,
    "bookings": 6,
    "vehicles": 6,
}


async def insights_node(state: AgentState) -> dict:
    # get_model returns CLOUD_PRIMARY (None only if GOOGLE_API_KEY is missing).
    model = get_model()
    if model is None:
        raise RuntimeError("GOOGLE_API_KEY not set — add it to .env to use AVA")

    tools = [t for t in get_tools_for_role(state["role"], state["user_id"]) if t.name in _TOOLS]
    messages = state["messages"]

    # ── Business-analysis fast path (deterministic) ───────────────────────────
    analysis_type = detect_analysis_mode(_last_human_text(messages))
    if analysis_type:
        tool_obj = next((t for t in tools if t.name == "run_business_analysis"), None)
        if tool_obj:
            # Seasonality and pricing correlation need a long window to say
            # anything; revenue/booking/fleet questions read "recent" as ~6 months.
            months = _WINDOW_MONTHS.get(analysis_type, 6)
            args = {"analysis_type": analysis_type, "months_back": months}
            result = await tool_obj.ainvoke(args)
            # Compact payload for the app (charts/KPIs/insights); the raw data
            # stays server-side only.  `mode` drives which layout the
            # AnalyticsCard renders; analysis_type stays for older clients.
            payload = {
                "analysis_type": result.get("analysis_type"),
                "mode": result.get("mode", result.get("analysis_type")),
                "title": result.get("title"),
                "charts": result.get("charts", []),
                "kpis": result.get("kpis", []),
                "insights": result.get("insights", []),
            }
            # Emit a well-formed tool-call sequence: (1) it gives the safety
            # node real ToolMessage evidence for the narrative's numbers, and
            # (2) this thread's history stays valid for future Gemini turns
            # (a dangling ToolMessage without a matching call would 400).
            call_id = f"analysis-{uuid4().hex[:8]}"
            call_msg = AIMessage(content="", tool_calls=[
                {"name": "run_business_analysis", "args": args, "id": call_id}])
            tool_msg = ToolMessage(
                content=json.dumps({
                    "analysis_type": result.get("analysis_type"),
                    "charts": len(payload["charts"]),
                    "kpis": len(payload["kpis"]),
                    "status": "ok",
                }),
                tool_call_id=call_id,
            )
            return {"messages": [call_msg, tool_msg, AIMessage(
                content=result.get("narrative", "Analysis complete."),
                additional_kwargs={"analytics": payload},
            )]}

    model_with_tools = model.bind_tools(tools)

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
            synthesis = await model.ainvoke(with_persona([*messages, response, tool_msg]))
            return {"messages": [response, tool_msg, synthesis]}

    return {"messages": [response]}


def build_graph():
    g = StateGraph(AgentState)
    g.add_node("insights", insights_node)
    g.add_edge(START, "insights")
    g.add_edge("insights", END)
    return g.compile(checkpointer=MemorySaver())
