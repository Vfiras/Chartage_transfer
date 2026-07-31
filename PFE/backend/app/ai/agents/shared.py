"""
Shared state definition and confirmation-gate utilities for all AVA sub-agents.

The confirmation gate pattern (run_with_confirmation) is used by Booking (action
path), Feedback, and Operations — centralised here so the logic isn't duplicated.
"""
from __future__ import annotations

import json
from typing import Annotated, Any, Optional

from langchain_core.messages import AIMessage, SystemMessage, ToolMessage
from langgraph.graph.message import add_messages
from typing_extensions import TypedDict


# ---------------------------------------------------------------------------
# Shared customer-facing persona
# ---------------------------------------------------------------------------
# Every user-facing model call in every sub-agent must run with this system
# prompt prepended (use with_persona()).  Without it the model defaults
# to a developer/tutorial voice and leaks tool names, code, JSON, and internal
# field names into user-facing text (see the 'how do I track my ride?' bug).

AVA_PERSONA_PROMPT = (
    "You are AVA, a customer-facing support concierge for Carthage Transfer, a "
    "premium chauffeur and airport-transfer service. You speak directly to the "
    "customer (a client or an admin).\n\n"
    "STRICT RULES — these override every other instinct:\n"
    "1. NEVER reveal how the system works internally. Do not mention tool names, "
    "function names, method names, parameter names, or internal field names "
    "(for example: get_trip_history, submit_claim, config, _id, user_id, "
    "trip_type, status, departure_date). The customer must never see them.\n"
    "2. NEVER output code, code blocks, triple backticks, or raw JSON. Write only "
    "in plain, natural-language sentences.\n"
    "3. ALWAYS translate data into plain language. Describe what is true for the "
    "customer's trip, booking, or account — not how the system stored or fetched "
    "it. Say 'Your trip from Tunis to Hammamet is confirmed', never 'the status "
    "field shows confirmed'.\n"
    "4. If the customer asks 'how do I do X', answer the way a human concierge "
    "would: a direct answer or simple everyday steps. Never explain an API, a "
    "function, or how to write code.\n"
    "5. NEVER state a specific named fact — a brand name, a company name, a number, "
    "a product name, or a specific policy detail — unless it appears verbatim or "
    "near-verbatim in the knowledge base context provided to you this turn. "
    "If the retrieved context does not name it, do not name it. "
    "Instead say: 'I don't have that specific detail on hand — please contact our "
    "team directly for an accurate answer.'\n"
    "6. You are the customer's DIRECT interface to their account. You have tools to "
    "look up trips, cancel bookings, modify reservations, submit complaints, and "
    "check loyalty rewards. NEVER tell the customer to navigate the app manually, "
    "go to a section, log into a website, or contact a separate support channel for "
    "something you can do directly this turn. Use your tools. If something is truly "
    "outside your capability, say so — but this should be rare.\n"
    "7. Be warm, concise, and professional, with a discreet luxury-service tone."
)


def with_persona(messages: list) -> list:
    """Prepend the AVA persona system message to a message list before any
    user-facing model call.  Centralised so every agent stays consistent."""
    return [SystemMessage(content=AVA_PERSONA_PROMPT), *messages]


async def synthesize(messages: list, role: str) -> Any:
    """Run a prose-synthesis call — turning a tool's raw JSON result into
    customer-facing prose.  Routing is flat: every request goes to Gemini
    (CLOUD_PRIMARY) via invoke_with_fallback, which obeys the 'exact values
    only' rules and reasons correctly over the tool data.
    """
    from app.ai.model_router import invoke_with_fallback

    return await invoke_with_fallback(messages)


def extract_text(response: Any) -> str:
    """Flatten an LLM response's content to plain, human-readable text.

    Handles both content shapes we see in production:
      - a plain string (most providers), and
      - a structured block list (Gemini 2.5):
            [{"type": "text", "text": "...", "extras": {"signature": "..."}}, ...]
        Only the visible text is kept; 'extras', 'signature', and non-text
        blocks (e.g. reasoning) are discarded entirely.

    Accepts either a message object (uses its .content) or a raw content value,
    so callers can pass `msg` or `msg.content` interchangeably.
    """
    content = getattr(response, "content", response)

    if isinstance(content, str):
        return content

    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict):
                # Keep only visible text blocks; skip reasoning/extras/signature.
                if block.get("type", "text") == "text":
                    text = block.get("text")
                    if text:
                        parts.append(str(text))
        return "".join(parts).strip()

    # Unknown shape — last-resort stringify so we never crash a response path.
    return str(content)


# ---------------------------------------------------------------------------
# Shared agent state
# ---------------------------------------------------------------------------

class AgentState(TypedDict):
    messages: Annotated[list, add_messages]
    role: str
    user_id: str
    pending_action: Optional[dict]          # tool name + args awaiting user confirmation
    awaiting_confirmation: bool
    next_node: Optional[str]                # used by booking agent's internal router
    # Booking disambiguation fields (Bug 2)
    candidate_bookings: Optional[list]      # upcoming bookings when user omits a specific ID
    awaiting_booking_selection: bool        # waiting for user to pick from candidate_bookings
    pending_selection_action: Optional[str] # "cancel" | "update" — action to take once resolved


# ---------------------------------------------------------------------------
# Confirmation-keyword helpers
# ---------------------------------------------------------------------------

_AFFIRM = frozenset({
    "yes", "oui", "confirm", "go ahead", "proceed", "ok", "sure",
    "yep", "yeah", "do it", "agreed", "affirmative",
})
_NEGATE = frozenset({
    "no", "non", "cancel", "stop", "abort", "nope", "dont", "don't",
    "nah", "negative", "nevermind", "never mind",
})


def is_affirmation(text: str) -> bool:
    lower = text.lower().strip()
    return any(kw in lower for kw in _AFFIRM)


def is_negation(text: str) -> bool:
    lower = text.lower().strip()
    return any(kw in lower for kw in _NEGATE)


def _last_human_text(messages: list) -> str:
    for msg in reversed(messages):
        if hasattr(msg, "type") and msg.type == "human":
            return str(msg.content)
        if isinstance(msg, tuple) and len(msg) == 2 and msg[0] == "human":
            return str(msg[1])
    return ""


def safe_tool_args(tool_obj: Any, raw_args: dict) -> dict:
    """Filter raw LLM args to only the fields the tool schema declares.

    The model sometimes emits {"args": {}} or other stray keys for tools
    with empty schemas.  Passing those through causes Python keyword-arg errors
    in the underlying function.  This strips anything the schema doesn't know.
    """
    schema = getattr(tool_obj, "args_schema", None)
    if schema is None:
        return {}
    known = set(getattr(schema, "model_fields", {}).keys())
    return {k: v for k, v in raw_args.items() if k in known}


# ---------------------------------------------------------------------------
# Customer-facing confirmation copy
# ---------------------------------------------------------------------------
# The confirmation gate must never expose tool names, parameter keys, raw JSON,
# or None values.  These helpers translate a pending tool call into natural
# concierge language for both the proposal ("I'd like to …") and the result
# ("Done — …").  Only values that are actually present are woven in.

def _clean(val: Any) -> Optional[str]:
    """Return a stripped string for a real value, or None for empty/None."""
    if val is None:
        return None
    s = str(val).strip()
    return s or None


def _proposal_phrase(tool_name: str, args: dict) -> str:
    """Natural verb phrase describing what AVA is about to do — no internals."""
    action = (_clean(args.get("action")) or "").lower()

    if tool_name == "submit_claim":
        return "submit your complaint"

    if tool_name == "create_booking":
        dep, arr = _clean(args.get("departure")), _clean(args.get("arrival"))
        if dep and arr:
            return f"create your booking from {dep} to {arr}"
        return "create this booking"

    if tool_name == "update_booking":
        return "update this booking"

    if tool_name == "cancel_booking":
        return "cancel your booking"

    if tool_name == "manage_fleet":
        name = _clean(args.get("name"))
        if action == "toggle_availability":
            # The target state is carried in the proposed args.
            avail = args.get("availability")
            if avail is True:
                return "make this vehicle available"
            if avail is False:
                return "make this vehicle unavailable"
            return "change this vehicle's availability"
        return {
            "create": f"add {name or 'a new vehicle'} to the fleet",
            "update": "update this vehicle's details",
            "delete": "remove this vehicle from the fleet",
            "list": "pull up the current fleet list",
        }.get(action, "make this fleet change")

    if tool_name == "manage_pricing_rules":
        return "show the current pricing rules" if action == "get" \
            else "update the pricing rules"

    if tool_name == "manage_suppliers":
        name = _clean(args.get("name"))
        return {
            "create": f"add {name or 'a new supplier'} as a supplier",
            "update": "update this supplier's details",
            "update_status": "change this supplier's status",
            "delete": "remove this supplier",
            "list": "pull up the supplier list",
        }.get(action, "make this supplier change")

    if tool_name == "manage_promotions":
        code = _clean(args.get("code"))
        if action == "toggle":
            # Promo toggle has no target in args (it flips current state), so the
            # gate resolves the resulting state from the DB into '_resulting_active'.
            resulting = args.get("_resulting_active")
            if resulting is True:
                return "make this promo code active"
            if resulting is False:
                return "make this promo code inactive"
            return "switch this promo code on or off"
        return {
            "create": f"create the promo code {code}" if code else "create a new promo code",
            "update": "update this promo code",
            "delete": "remove this promo code",
            "list": "pull up the promotions list",
        }.get(action, "make this promotion change")

    if tool_name == "update_booking_status":
        st = _clean(args.get("new_status"))
        return f"update this booking's status to {st}" if st \
            else "update this booking's status"

    # Generic safe fallback — never expose the tool name.
    return "carry out this action"


def format_tool_summary(tool_name: str, tool_args: dict) -> str:
    """Customer-facing confirmation prompt shown before a state-changing action."""
    phrase = _proposal_phrase(tool_name, tool_args or {})
    return (
        f"I'd like to {phrase}. "
        "Reply **yes** to confirm or **no** to cancel."
    )


def humanize_result(tool_name: str, tool_args: dict, result: Any) -> str:
    """One-line natural confirmation of a completed action — never raw JSON.

    If the tool returned an error dict, surface that error in plain language
    instead of falsely reporting success.
    """
    if isinstance(result, dict) and result.get("error"):
        return f"I wasn't able to do that — {result['error']}"

    args = tool_args or {}
    action = (_clean(args.get("action")) or "").lower()

    if tool_name == "submit_claim":
        return "Done — your complaint has been submitted. Our team will review it shortly."
    if tool_name == "create_booking":
        return "Done — your booking has been created."
    if tool_name == "update_booking":
        return "Done — your booking has been updated."
    if tool_name == "cancel_booking":
        return "Done — your booking has been cancelled."

    if tool_name == "manage_fleet":
        if action == "toggle_availability":
            car = result.get("car") if isinstance(result, dict) else None
            if isinstance(car, dict) and "availability" in car:
                return f"Done — the vehicle is now {'available' if car['availability'] else 'unavailable'}."
            return "Done — the vehicle's availability has been updated."
        return {
            "create": "Done — the vehicle has been added to the fleet.",
            "update": "Done — the vehicle's details have been updated.",
            "delete": "Done — the vehicle has been removed from the fleet.",
            "list": "Done — I've pulled up the current fleet.",
        }.get(action, "Done — the fleet has been updated.")

    if tool_name == "manage_pricing_rules":
        return "Done — I've retrieved the current pricing rules." if action == "get" \
            else "Done — the pricing rules have been updated."

    if tool_name == "manage_suppliers":
        return {
            "create": "Done — the supplier has been added.",
            "update": "Done — the supplier's details have been updated.",
            "update_status": "Done — the supplier's status has been updated.",
            "delete": "Done — the supplier has been removed.",
            "list": "Done — I've pulled up the supplier list.",
        }.get(action, "Done — the supplier records have been updated.")

    if tool_name == "manage_promotions":
        if action == "toggle":
            promo = result.get("promotion") if isinstance(result, dict) else None
            if isinstance(promo, dict) and "active" in promo:
                return f"Done — the promo code is now {'active' if promo['active'] else 'inactive'}."
            return "Done — the promo code's status has been updated."
        return {
            "create": "Done — the promo code has been created.",
            "update": "Done — the promo code has been updated.",
            "delete": "Done — the promo code has been removed.",
            "list": "Done — I've pulled up the promotions list.",
        }.get(action, "Done — the promotions have been updated.")

    if tool_name == "update_booking_status":
        st = _clean(args.get("new_status"))
        return f"Done — the booking status has been updated to {st}." if st \
            else "Done — the booking status has been updated."

    return "Done — your request has been completed."


async def resolve_proposal_state(tool_name: str, args: dict) -> dict:
    """Enrich args so a toggle proposal can state its resulting direction.

    manage_fleet[toggle_availability] already carries the target 'availability'
    in args, so nothing is needed.  manage_promotions[toggle] flips the current
    state with no target in args, so we read the current state from the DB and
    stash the resulting value under the private key '_resulting_active'
    (safe_tool_args strips it before the real tool call).
    """
    action = (_clean(args.get("action")) or "").lower()
    if tool_name == "manage_promotions" and action == "toggle":
        promo_id = _clean(args.get("promo_id"))
        if promo_id:
            from app.core.database import get_database
            promo = await get_database().promotions.find_one({"_id": promo_id})
            if promo is not None:
                return {**args, "_resulting_active": not promo.get("active", True)}
    return args


# ---------------------------------------------------------------------------
# Reusable confirmation gate
# ---------------------------------------------------------------------------

async def run_with_confirmation(
    state: AgentState,
    model_with_tools: Any,
    tool_map: dict,
) -> dict:
    """
    Confirmation gate for state-changing tools.

    If awaiting_confirmation is True:
      - affirmation  → execute pending_action, clear gate state
      - negation     → cancel, clear gate state
      - ambiguous    → re-ask

    Otherwise:
      - Ask LLM to select a tool.
      - If tool call returned: surface a confirmation prompt instead of
        executing immediately, set pending_action + awaiting_confirmation.
      - If plain text returned: forward as-is.
    """
    messages = state["messages"]

    if state.get("awaiting_confirmation") and state.get("pending_action"):
        text = _last_human_text(messages)
        pending = state["pending_action"]

        if is_affirmation(text):
            tool_obj = tool_map.get(pending["name"])
            if tool_obj is None:
                return {
                    "messages": [AIMessage(content=f"Error: tool '{pending['name']}' not found.")],
                    "pending_action": None,
                    "awaiting_confirmation": False,
                }
            result = await tool_obj.ainvoke(safe_tool_args(tool_obj, pending["args"]))
            # The ToolMessage carries the raw JSON as INTERNAL evidence only
            # (safety_check reads it to confirm a tool actually ran); it is never
            # surfaced.  The user-facing AIMessage is a humanized one-liner.
            return {
                "messages": [
                    ToolMessage(
                        content=json.dumps(result, default=str),
                        tool_call_id=f"confirmation_gate_{pending['name']}",
                        name=pending["name"],
                    ),
                    AIMessage(
                        content=humanize_result(pending["name"], pending["args"], result)
                    ),
                ],
                "pending_action": None,
                "awaiting_confirmation": False,
            }

        if is_negation(text):
            return {
                "messages": [AIMessage(content="Action cancelled. Let me know if there's anything else I can help with.")],
                "pending_action": None,
                "awaiting_confirmation": False,
            }

        # Ambiguous — re-ask without re-invoking the LLM
        return {
            "messages": [AIMessage(content=f"Please reply **yes** to confirm or **no** to cancel.\n\n{pending['summary']}")],
        }

    # No pending action — let the LLM decide what to do.
    # Persona prepended so any plain-text reply (e.g. to a "how do I…" question
    # that doesn't trigger a tool) stays in concierge voice, not developer voice.
    response = await model_with_tools.ainvoke(with_persona(messages))

    if response.tool_calls:
        tc = response.tool_calls[0]
        tool_name = tc["name"]
        tool_args = tc["args"]
        # TODO(read-only-gating): operations_agent routes ALL its tools through
        # this gate, including read-only actions — manage_fleet[list],
        # manage_pricing_rules[get], manage_suppliers[list], manage_promotions[list].
        # Those get a yes/no confirmation and then a "Done — I've pulled up …"
        # one-liner that DROPS the data they fetched.  They should not be gated at
        # all; reroute read actions through a synthesis path like insights_agent.py
        # instead.  Scoped out of the persona-leak fix — see PROJECT_CONTEXT.md §19.
        tool_args = await resolve_proposal_state(tool_name, tool_args)
        summary = format_tool_summary(tool_name, tool_args)
        return {
            "messages": [AIMessage(content=summary)],
            "pending_action": {"name": tool_name, "args": tool_args, "summary": summary},
            "awaiting_confirmation": True,
        }

    return {
        "messages": [response],
        "pending_action": None,
        "awaiting_confirmation": False,
    }
