"""
Top-level AVA supervisor graph.

Nodes (in order per turn):
  classify_intent  — Gemini labels message as one of 6 domains.
                     Defensive: if model output is ambiguous, keyword-matches
                     the user's text instead of crashing.
                     Special case: if the last AI message was a confirmation
                     prompt ("Reply **yes** to confirm..."), skip re-classification
                     and reuse the current domain so confirmation flows continue.
                     Every role uses Gemini → RuntimeError if no key (correct).
  role_gate        — pure Python; blocks client from operations/insights,
                     writes audit_log access_denied, returns polite refusal.
  dispatch         — invokes the compiled sub-agent graph for the domain.
                     Sub-agent threads are keyed: {supervisor_thread_id}_{domain}.
  safety_check     — deterministic cross-check: if response claims success but
                     no successful tool execution backs it up, overrides the
                     response and writes audit_log safety_override.
  session_write    — appends (human, assistant) turn to chat_sessions for user_id,
                     adds the final AI message to supervisor state messages.

Edges:
  START → classify → gate
  gate → dispatch → safety → session_write → END   (if access allowed)
  gate → session_write → END                        (if access denied)
"""
from __future__ import annotations

import json
import re
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from datetime import datetime, timezone
from typing import Annotated, Any, Optional

from langchain_core.messages import AIMessage
from langchain_core.runnables import RunnableConfig
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.graph.message import add_messages
from typing_extensions import TypedDict

from app.ai.agents.shared import _last_human_text, extract_text
from app.ai.model_router import invoke_with_fallback
from app.core.database import get_database


# ---------------------------------------------------------------------------
# Supervisor state
# ---------------------------------------------------------------------------

class SupervisorState(TypedDict):
    messages: Annotated[list, add_messages]
    role: str
    user_id: str
    domain: Optional[str]
    _access_denied: bool
    _dispatch_delta: Optional[list]   # new messages from last sub-agent dispatch
    _pending_ai: Optional[str]        # final response text; safety_check may override
    _analytics_payload: Optional[dict]  # charts/KPIs from run_business_analysis, for the SSE layer


# ---------------------------------------------------------------------------
# Domain classification
# ---------------------------------------------------------------------------

_VALID_DOMAINS = frozenset({"booking", "support", "loyalty", "feedback", "operations", "insights"})

_CLASSIFY_PROMPT = (
    "Classify the following user message into exactly one of these six labels:\n"
    "booking, support, loyalty, feedback, operations, insights\n\n"
    "- booking: the user's own personal reservations — creating, modifying, cancelling, or viewing.\n"
    "  Examples: 'my trips', 'my upcoming ride', 'show my bookings', 'my recent trips', 'my next trip'.\n"
    "- support: policy questions, FAQs, cancellation rules, terms\n"
    "- loyalty: promo codes, points, tier, rewards\n"
    "- feedback: complaints, issues, claims\n"
    "- operations: admin-only fleet/pricing — manage vehicles, set prices, suppliers, promotions\n"
    "- insights: admin-only analytics — ALL-user reports, dashboards, revenue, booking statistics\n\n"
    "RULE: any message containing 'my trips', 'my bookings', or 'my rides' is always booking.\n"
    "Reply with exactly one bare word — nothing else."
)

_KEYWORD_MAP: list[tuple[frozenset[str], str]] = [
    (frozenset({"book", "booking", "reserve", "reservation", "cancel", "trip", "ride",
                "vip car", "vehicle", "recommend", "schedule", "departure",
                "modify booking", "update booking"}), "booking"),
    # NOTE: "car" intentionally absent — it appears as a substring of "Carthage", which would
    # mis-route any message mentioning the company name to the booking agent.
    (frozenset({"policy", "cancellation policy", "refund", "terms", "conditions", "faq",
                "how long", "rules", "allowed", "permitted", "charge"}), "support"),
    (frozenset({"promo", "coupon", "discount", "points", "reward", "loyalty", "tier",
                "bronze", "silver", "gold", "benefit"}), "loyalty"),
    (frozenset({"complaint", "claim", "issue", "problem", "late", "rude", "wrong",
                "feedback", "report driver"}), "feedback"),
    (frozenset({"fleet", "supplier", "promotion", "manage", "vehicle price",
                "add car", "delete car"}), "operations"),
    (frozenset({"dashboard", "analytics", "overview", "stats", "statistics",
                "users list", "all bookings", "revenue", "report",
                # business-analysis phrases (see analysis_triggers.py)
                "business review", "full review", "full analysis",
                "how are we doing", "seasonal", "peak season", "best months",
                "pricing impact", "vehicle performance", "business health",
                "show me the numbers"}), "insights"),
]


_QUESTION_STARTERS = frozenset({"what", "is", "does", "did", "can", "could", "would", "should"})
_ADMIN_MOD_VERBS = frozenset({"change", "update", "set", "modify", "adjust", "configure"})
_PRICE_TERMS = frozenset({"price", "pricing", "rate", "tariff"})

# Interrogative booking-action detection — "How do I cancel my booking?" is a
# support FAQ question, not a real cancellation request.  We distinguish it from
# "Please cancel my booking booking-test-ava-001" (has a specific booking ID).
_HOW_STARTERS = ("how do i", "how can i", "how would i", "how to ")
_BOOKING_ACTION_WORDS = frozenset({"cancel", "modify", "change my booking", "update my booking"})
_BOOKING_ID_RE = re.compile(r"booking-\w")


def _is_faq_about_booking(text: str) -> bool:
    """Return True when a message is a process/policy question phrased as booking vocabulary.

    'How do I cancel my booking?'  → True  (support FAQ)
    'Please cancel my booking booking-test-ava-001' → False (real action request)

    Criteria:
    - starts with or contains an interrogative starter ("how do i", "how to", …)
    - contains a booking action word (cancel, modify, …)
    - has no specific booking ID (booking-<id>)
    """
    lower = text.lower()
    return (
        any(lower.startswith(h) or f" {h} " in lower for h in _HOW_STARTERS)
        and any(aw in lower for aw in _BOOKING_ACTION_WORDS)
        and not _BOOKING_ID_RE.search(lower)
    )


def _keyword_classify(text: str) -> Optional[str]:
    """Return the keyword-matched domain, or None if no keyword matched.

    Returning None instead of a default "support" lets the supervisor distinguish
    a POSITIVE keyword signal from a no-match fallback.  Guards 2b in
    classify_intent_node only fire on positive matches, so that the model's
    admin-domain classification is still trusted when no keyword covered the message.
    """
    lower = text.lower()
    words = lower.split()
    # Admin-intent pre-check: requires an imperative modification verb that appears
    # BEFORE a price/fleet term AND the opening three words contain no question word.
    # "change the price of the VIP car" → verb(0) < price(11) → operations.
    # "did the price for the VIP car change recently?" → "did" is a question opener → skipped.
    early_is_question = any(w.startswith(q) for w in words[:3] for q in _QUESTION_STARTERS)
    if not early_is_question:
        for verb in _ADMIN_MOD_VERBS:
            if verb not in lower:
                continue
            verb_pos = lower.index(verb)
            for term in _PRICE_TERMS:
                if term in lower and lower.index(term) > verb_pos:
                    return "operations"
            if "fleet" in lower and lower.index("fleet") > verb_pos:
                return "operations"
    for keywords, domain in _KEYWORD_MAP:
        if any(kw in lower for kw in keywords):
            return domain
    return None  # no positive keyword match


# ---------------------------------------------------------------------------
# Lazy sub-agent cache
# ---------------------------------------------------------------------------

_SUB_AGENTS: dict[str, Any] = {}


def _get_sub_agent(domain: str) -> Any:
    if domain not in _SUB_AGENTS:
        if domain == "booking":
            from app.ai.agents.booking_agent import build_graph
        elif domain == "support":
            from app.ai.agents.support_agent import build_graph
        elif domain == "loyalty":
            from app.ai.agents.loyalty_agent import build_graph
        elif domain == "feedback":
            from app.ai.agents.feedback_agent import build_graph
        elif domain == "operations":
            from app.ai.agents.operations_agent import build_graph
        elif domain == "insights":
            from app.ai.agents.insights_agent import build_graph
        else:
            from app.ai.agents.support_agent import build_graph
        _SUB_AGENTS[domain] = build_graph()
    return _SUB_AGENTS[domain]


# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------

async def classify_intent_node(state: SupervisorState) -> dict:
    """Classify the user's intent into one of 6 domains.

    Sticky rule: if the previous AI message was a confirmation gate prompt
    ("Reply **yes** to confirm..."), reuse the current domain so the confirmation
    flow is not broken by re-classifying the user's "yes"/"no" reply.
    """
    base_reset = {"_access_denied": False, "_dispatch_delta": None,
                  "_pending_ai": None, "_analytics_payload": None}
    messages = state["messages"]
    role = state["role"]

    # Sticky follow-up check: when the previous turn asked a question whose
    # answer carries no routable keywords of its own — a bare "2" for a
    # booking selection, or "the date" when asked what to change — keep the
    # current domain. Re-classifying those from scratch sent them to support,
    # which broke the select-a-booking flow mid-way.
    _STICKY_PROMPTS = (
        "reply **yes** to confirm",
        "please reply **yes** to confirm",
        "please reply with the number",
        "what would you like to change?",
    )
    for msg in reversed(messages):
        if hasattr(msg, "type") and msg.type == "ai":
            content = extract_text(msg).lower()
            if any(marker in content for marker in _STICKY_PROMPTS):
                return {**base_reset, "domain": state.get("domain", "support")}
            break

    last_human = _last_human_text(messages)

    # Guard 0: explicit business-analysis phrases from an ADMIN always route to
    # insights, deterministically — no classification call needed. (For a
    # client the same phrases fall through; keyword guards + role_gate handle them.)
    if role == "admin":
        from app.ai.analysis_triggers import detect_analysis_type
        if detect_analysis_type(last_human):
            return {**base_reset, "domain": "insights"}

    # invoke_with_fallback raises RuntimeError immediately if GOOGLE_API_KEY is unset
    response = await invoke_with_fallback(
        messages=[("system", _CLASSIFY_PROMPT), ("human", last_human)],
    )

    # extract_text() guards against Gemini returning block-list content here,
    # which would otherwise crash .strip() on the admin classification path.
    raw = re.sub(r"[^a-z]", "", extract_text(response).strip().lower())
    kw = _keyword_classify(last_human)

    # Guard 1: keyword admin-intent always wins over model for a client.
    # "Change the price of the VIP car" keyword→operations + client → role_gate fires.
    if kw in ("operations", "insights") and role == "client":
        return {**base_reset, "domain": kw}

    # Guard 2b: when keyword POSITIVELY identifies a non-admin domain for a client but
    # the model returns an admin domain, trust the keyword.
    # kw=None (no keyword matched) is explicitly skipped so the model's admin
    # classification still gates clients on admin-sounding questions with no keyword hit.
    # Covers:
    #   booking-03: keyword→booking (via "recommend"), model→operations → force booking
    #   Bug 5:      keyword→support  (via "how long"),  model→operations → force support
    if (kw is not None
            and kw not in ("operations", "insights")
            and raw in ("operations", "insights")
            and role == "client"):
        return {**base_reset, "domain": kw}

    # Guard 3: interrogative booking-action phrases are support FAQ, not booking actions.
    # "How do I cancel my booking?" → support.
    # "Please cancel my booking booking-test-ava-001" → booking (has specific ID, not FAQ).
    # Fires even when the model returns "booking" because the keyword "cancel" is in the
    # booking keyword set but the message is asking about process, not triggering one.
    if _is_faq_about_booking(last_human) and raw == "booking":
        return {**base_reset, "domain": "support"}

    if raw in _VALID_DOMAINS:
        return {**base_reset, "domain": raw}

    # Final fallback: kw or "support" (kw may be None if no keyword matched).
    return {**base_reset, "domain": kw or "support"}


async def role_gate_node(state: SupervisorState) -> dict:
    """Block client role from admin-domain agents; log every denial to audit_log."""
    domain = state.get("domain") or "support"
    role = state["role"]
    user_id = state["user_id"]

    if domain in ("operations", "insights") and role != "admin":
        db = get_database()
        await db.audit_log.insert_one({
            "user_id": user_id,
            "role": role,
            "event": "access_denied",
            "attempted_domain": domain,
            "timestamp": datetime.now(timezone.utc),
        })
        refusal = (
            "I'm sorry, but that request requires administrative access. "
            "Please contact your administrator if you believe this is an error."
        )
        return {"_access_denied": True, "_pending_ai": refusal}

    return {"_access_denied": False}


def _route_after_gate(state: SupervisorState) -> str:
    return "session_write" if state.get("_access_denied") else "dispatch"


async def dispatch_node(state: SupervisorState, config: RunnableConfig) -> dict:
    """Invoke the correct sub-agent graph and capture its new messages."""
    domain = state.get("domain") or "support"
    role = state["role"]
    user_id = state["user_id"]
    thread_id = config["configurable"].get("thread_id", "default")

    sub_agent = _get_sub_agent(domain)
    sub_config = {"configurable": {"thread_id": f"{thread_id}_{domain}"}}

    # Record message count before dispatch so we can compute the delta
    before_snapshot = await sub_agent.aget_state(sub_config)
    before_count = (
        len(before_snapshot.values.get("messages", []))
        if (before_snapshot and before_snapshot.values)
        else 0
    )

    # Pass only the latest human message; sub-agent's MemorySaver handles history
    last_human_msg = next(
        (m for m in reversed(state["messages"]) if hasattr(m, "type") and m.type == "human"),
        None,
    )
    sub_input: dict = {"messages": [last_human_msg]}
    if before_count == 0:
        # First call for this domain thread — seed identity fields and all optional state
        sub_input.update({
            "role": role,
            "user_id": user_id,
            "pending_action": None,
            "awaiting_confirmation": False,
            "next_node": None,
            "candidate_bookings": None,
            "awaiting_booking_selection": False,
            "pending_selection_action": None,
        })

    result = await sub_agent.ainvoke(sub_input, config=sub_config)
    new_msgs = result["messages"][before_count:]

    # Extract last AI text for safety check + session write.
    # extract_text() flattens Gemini's structured block-list content (admin
    # agents) to plain text; for llama/string content it is a no-op.
    last_ai_text: str = "(no response)"
    analytics_payload: Optional[dict] = None
    for msg in reversed(new_msgs):
        if hasattr(msg, "type") and msg.type == "ai":
            last_ai_text = extract_text(msg)
            # The insights agent attaches chart/KPI data for the app to render.
            analytics_payload = (getattr(msg, "additional_kwargs", None) or {}).get("analytics")
            break

    return {"_dispatch_delta": list(new_msgs), "_pending_ai": last_ai_text,
            "_analytics_payload": analytics_payload}


# ---------------------------------------------------------------------------
# Safety check
# ---------------------------------------------------------------------------

_SUCCESS_KEYWORDS = frozenset({
    "confirmed", "completed", "cancelled", "created", "updated", "submitted",
})


def _tool_ran_successfully(messages: list) -> bool:
    """Return True if a ToolMessage with non-error content appears in messages."""
    from langchain_core.messages import ToolMessage

    for msg in messages:
        if not isinstance(msg, ToolMessage):
            continue
        try:
            parsed = json.loads(str(msg.content))
            if isinstance(parsed, dict) and "error" in parsed:
                return False
        except (json.JSONDecodeError, ValueError):
            pass
        return True  # ToolMessage present and not an error dict
    return False


async def safety_check_node(state: SupervisorState) -> dict:
    """Deterministic guard: cross-check success-claiming language against actual tool evidence."""
    pending = state.get("_pending_ai") or ""
    delta = state.get("_dispatch_delta") or []

    lower = pending.lower()
    claims_success = any(kw in lower for kw in _SUCCESS_KEYWORDS)

    # If the response is a confirmation prompt, success keywords are expected — skip
    is_confirmation_prompt = "reply **yes** to confirm" in lower or "i'd like to run" in lower

    tool_ran = _tool_ran_successfully(delta)

    if claims_success and not tool_ran and not is_confirmation_prompt:
        db = get_database()
        await db.audit_log.insert_one({
            "event": "safety_override",
            "user_id": state.get("user_id", "unknown"),
            "role": state.get("role", "unknown"),
            "domain": state.get("domain", "unknown"),
            "original_response": pending[:500],
            "timestamp": datetime.now(timezone.utc),
        })
        override = (
            "I apologize — something went wrong processing your request. "
            "Please try again or contact support if the problem persists."
        )
        return {"_pending_ai": override}

    return {}


# ---------------------------------------------------------------------------
# Session persistence
# ---------------------------------------------------------------------------

async def session_write_node(state: SupervisorState) -> dict:
    """Write the turn to chat_sessions and add the AI message to supervisor state."""
    pending_ai = state.get("_pending_ai") or ""
    user_id = state["user_id"]
    last_human = _last_human_text(state["messages"])

    db = get_database()
    now = datetime.now(timezone.utc)
    await db.chat_sessions.update_one(
        {"user_id": user_id},
        {
            "$push": {
                "turns": {
                    "human": last_human,
                    "assistant": pending_ai,
                    "timestamp": now,
                }
            },
            "$set": {"updated_at": now},
            "$setOnInsert": {"user_id": user_id, "created_at": now},
        },
        upsert=True,
    )

    # Pass the analytics payload through in this node's update so the SSE
    # layer (which handles the session_write update) can emit it to the app.
    analytics = state.get("_analytics_payload")
    final_msg = AIMessage(
        content=pending_ai,
        additional_kwargs={"analytics": analytics} if analytics else {},
    )
    return {"messages": [final_msg], "_analytics_payload": analytics}


# ---------------------------------------------------------------------------
# Graph assembly
# ---------------------------------------------------------------------------

def build_supervisor() -> Any:
    g = StateGraph(SupervisorState)

    g.add_node("classify", classify_intent_node)
    g.add_node("gate", role_gate_node)
    g.add_node("dispatch", dispatch_node)
    g.add_node("safety", safety_check_node)
    g.add_node("session_write", session_write_node)

    g.add_edge(START, "classify")
    g.add_edge("classify", "gate")
    g.add_conditional_edges(
        "gate",
        _route_after_gate,
        {"dispatch": "dispatch", "session_write": "session_write"},
    )
    g.add_edge("dispatch", "safety")
    g.add_edge("safety", "session_write")
    g.add_edge("session_write", END)

    return g.compile(checkpointer=MemorySaver())
