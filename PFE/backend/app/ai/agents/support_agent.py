"""
Support sub-agent — answers policy/FAQ questions via the RAG knowledge base.

Tool:  search_knowledge_base
Model: Gemini (CLOUD_PRIMARY)
Gate:  none — read-only
"""
from __future__ import annotations

import sys, os, json

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import SystemMessage, ToolMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from app.ai.agents.shared import (
    AVA_PERSONA_PROMPT, AgentState, safe_tool_args, synthesize, with_persona,
)
from app.ai.model_router import get_model
from app.ai.tool_registry import get_tools_for_role

_TOOLS = frozenset({"search_knowledge_base"})

_SUPPORT_ADDENDUM = (
    "\n\nRAG SYNTHESIS RULES (override any other instinct):\n"
    "- Answer from the retrieved knowledge base text only. NEVER cite page sections, "
    "website links, or document headings ('see our website footer', 'under Policies') "
    "that do not appear verbatim in the retrieved context.\n"
    "- NEVER state a specific named fact — a brand name, a number, a section name, or "
    "a specific policy detail — unless it appears verbatim or near-verbatim in the "
    "retrieved knowledge base text provided above. If the context doesn't name it, "
    "say 'I don't have that specific detail on hand — please contact our team directly.'\n"
    "- If the question is about an action the customer can take (cancel, modify, submit "
    "a complaint), close your response with a direct offer: 'If you'd like me to handle "
    "that for you right now, just say the word.' Do NOT tell the customer to navigate "
    "the app, check their email, or contact a separate support channel."
)

_SUPPORT_SYSTEM = AVA_PERSONA_PROMPT + _SUPPORT_ADDENDUM


def _with_support_persona(messages: list) -> list:
    """Merged persona + RAG rules as a single system message at position 0.

    Keeping the system role at position 0 (rather than appending a second
    SystemMessage after the conversation) avoids empty-content responses.
    """
    return [SystemMessage(content=_SUPPORT_SYSTEM), *messages]


async def support_node(state: AgentState) -> dict:
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
            # Synthesis runs on Gemini.  The RAG addendum forbids citing
            # facts/headings not in the retrieved text; Gemini follows it
            # reliably.
            synthesis = await synthesize(
                _with_support_persona([*messages, response, tool_msg]),
                state["role"],
            )
            return {"messages": [response, tool_msg, synthesis]}

    return {"messages": [response]}


def build_graph():
    g = StateGraph(AgentState)
    g.add_node("support", support_node)
    g.add_edge(START, "support")
    g.add_edge("support", END)
    return g.compile(checkpointer=MemorySaver())
