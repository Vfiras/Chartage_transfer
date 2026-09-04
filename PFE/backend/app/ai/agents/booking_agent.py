"""
Booking sub-agent — internal 4-node router.

classify_node       Gemini — routes LOOKUP / DISAMBIGUATE / ACTION / RESOLVE_SELECTION
lookup_node         Gemini — get_trip_history, recommend_vehicle (read-only)
disambiguate_node   no LLM — resolves missing booking reference before action
resolve_selection   no LLM — maps user's natural reply to a specific booking ID
action_node         Gemini — create/update/cancel + confirmation gate
"""
from __future__ import annotations

import json
import re
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import AIMessage, SystemMessage, ToolMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from app.ai.agents.shared import (
    AVA_PERSONA_PROMPT, AgentState, _last_human_text, extract_text,
    run_with_confirmation, safe_tool_args, with_persona,
)
from app.ai.model_router import get_model
from app.ai.tool_registry import get_tools_for_role

_LOOKUP_TOOLS  = frozenset({"get_trip_history", "recommend_vehicle"})
_ACTION_TOOLS  = frozenset({"create_booking", "update_booking", "cancel_booking"})

# Detect a specific booking reference in a user message, e.g. "booking-test-ava-001"
_BOOKING_REF_RE = re.compile(r"\bbooki\w*-\w", re.IGNORECASE)


def _has_booking_ref(text: str) -> bool:
    return bool(_BOOKING_REF_RE.search(text))


# ---------------------------------------------------------------------------
# Lookup synthesis system addendum (prepended AFTER AVA_PERSONA_PROMPT)
# ---------------------------------------------------------------------------
# Addresses two bugs:
#   Bug 1a: "How do I track my current ride?" — model deflects to "check the app"
#            instead of reporting the actual trip status from get_trip_history.
#   Bug 3:  "What car would you recommend?" — model invents vehicle names like
#            "Executive Sedan" instead of using the exact category/model from tool JSON.

_LOOKUP_ADDENDUM = (
    "\n\nBOOKING DATA RULES (override any other instinct):\n"
    "- When you have trip data from the tool, ALWAYS report the customer's ACTUAL "
    "trips and their current status. Never say 'check the app', 'navigate to a "
    "section', or 'contact support' when the tool result has the answer.\n"
    "- For vehicle recommendations: use ONLY the exact 'category', 'name', and "
    "'model' values present in the tool result JSON. NEVER invent descriptive "
    "variant names like 'Executive Sedan' or 'Standard Comfort Class' that do not "
    "appear verbatim in the data.\n"
    "- Describe trips by route (pickup to destination) and date. Never expose raw "
    "IDs, field names, or JSON.\n"
    "- If the tool returned an error, say so plainly and offer to help.\n"
    "\nMODIFYING A BOOKING:\n"
    "- Never call update_booking without at least one field to change. If the "
    "client has not said what to change, ask: 'What would you like to change? "
    "You can update the date, time, pickup address, destination, or passenger "
    "count.'\n"
    "- Before applying, state the SPECIFIC change back to them using the old and "
    "new values, e.g. 'Date: 27 Jul to 15 Aug, time: 14:00 to 15:00. Shall I "
    "apply that?' — never a bare 'shall I update this booking?'.\n"
    "- After the tool returns, report the exact changes from its `changes` list. "
    "If it returns no_changes_specified or values_unchanged, do NOT claim the "
    "booking was updated — ask what should be different instead."
)

_BOOKING_SYSTEM = AVA_PERSONA_PROMPT + _LOOKUP_ADDENDUM


def _with_booking_persona(messages: list) -> list:
    """Merged persona + booking-data rules as a single system message at position 0.

    Keeping the system role message first (rather than appending a second
    SystemMessage after the conversation) avoids empty-content responses.
    """
    return [SystemMessage(content=_BOOKING_SYSTEM), *messages]


# ---------------------------------------------------------------------------
# Support policy + action offer (used by support_agent, re-exported here for
# the "how do I cancel?" -> support -> offer pattern)
# ---------------------------------------------------------------------------
# Not used directly in this file, but the pattern below is mirrored in support_agent.py.


# ---------------------------------------------------------------------------
# Node 1 — intent classification (Gemini, no tools)
# ---------------------------------------------------------------------------

async def classify_node(state: AgentState) -> dict:
    """Route to the correct node based on intent and pending state.

    Priority order:
    1. awaiting_booking_selection  → resolve_selection (user picking from a list)
    2. awaiting_confirmation       → action          (user confirming/cancelling)
    3. LLM classification          → lookup | disambiguate
    """
    if state.get("awaiting_booking_selection"):
        return {"next_node": "resolve_selection"}

    if state.get("awaiting_confirmation"):
        return {"next_node": "action"}

    last_text = _last_human_text(state["messages"])

    model = get_model()

    classify_resp = await model.ainvoke([
        (
            "system",
            "You are a router. Classify the user's request as exactly one word.\n"
            "LOOKUP  — viewing trip history, tracking a current ride, getting vehicle "
            "recommendations, or checking any account info.\n"
            "ACTION  — creating, modifying, or cancelling a booking.\n"
            "Reply with exactly one word: LOOKUP or ACTION.",
        ),
        ("human", last_text),
    ])

    # extract_text() flattens Gemini's structured block-list content. Reading
    # .content directly worked only while every reply came back as a plain
    # string; the fallback model returns blocks, and .strip() then explodes.
    decision = extract_text(classify_resp).strip().upper()
    # Action requests go to disambiguate first (not action directly) so we can
    # resolve a missing booking reference without consuming Gemini quota.
    route = "disambiguate" if "ACTION" in decision else "lookup"
    return {"next_node": route}


def _route_booking(state: AgentState) -> str:
    return state.get("next_node") or "lookup"


# ---------------------------------------------------------------------------
# Node 2a — lookup (Gemini, read-only tools)
# ---------------------------------------------------------------------------

def _vehicle_template(result: dict) -> str:
    """Deterministic vehicle-recommendation reply built straight from the tool's
    DB values.  Used ONLY as a fallback when cloud synthesis is unavailable —
    uses the exact category/name/model verbatim so no name is ever fabricated.

    NOTE: this trusts the tool's preference-based 'recommended' field, which does
    not weigh luggage capacity; cloud synthesis (the primary path) reasons over
    the eligible list and picks a better-fitting vehicle.
    """
    rec = (result or {}).get("recommended") or {}
    name = rec.get("name", "")
    model_name = rec.get("model", "")
    seats = rec.get("seats", "?")
    luggage = rec.get("luggage")
    est = rec.get("estimated_price_eur")
    # Real fleet names ARE the display names now (e.g. "Comfort Sedan",
    # "Mercedes V Class - Executive"); append the model only when it differs.
    vehicle_str = name or rec.get("category", "vehicle")
    if model_name and model_name.lower() != vehicle_str.lower():
        vehicle_str = f"{vehicle_str} ({model_name})"
    luggage_clause = f" and {luggage} bags" if luggage else ""
    price_clause = f" Estimated around {est} EUR for a typical transfer." if est else ""
    return (
        f"Based on your requirements, I'd recommend the **{vehicle_str}** "
        f"— it seats up to {seats} passengers{luggage_clause}.{price_clause} "
        f"Would you like me to book it for you?"
    )


async def lookup_node(state: AgentState) -> dict:
    tools = [t for t in get_tools_for_role(state["role"], state["user_id"])
             if t.name in _LOOKUP_TOOLS]
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
            synth_input = _with_booking_persona([*messages, response, tool_msg])

            # Synthesis runs on Gemini, which obeys the exact-values rule and
            # reasons over the eligible list (no fused/invented descriptors like
            # 'Standard Comfort sedan', and luggage limits respected).
            synth_model = get_model()
            try:
                if synth_model is None:
                    raise RuntimeError("no cloud synthesis tier configured")
                synthesis = await synth_model.ainvoke(synth_input)
                return {"messages": [response, tool_msg, synthesis]}
            except Exception as exc:  # noqa: BLE001
                print(f"[booking.lookup] cloud synthesis failed ({exc!r}); using fallback")
                if tc["name"] == "recommend_vehicle":
                    # Deterministic template (correct names) — guarantees a valid
                    # reply when Gemini is unavailable (quota/outage).
                    return {"messages": [response, tool_msg,
                                         AIMessage(content=_vehicle_template(result))]}
                raise

    return {"messages": [response]}


# ---------------------------------------------------------------------------
# Node 2b — disambiguation (no LLM — pure Python + one DB call)
# ---------------------------------------------------------------------------
# Resolves missing booking references BEFORE the Gemini action gate fires.
# Three outcomes:
#   0 candidates → plain "no bookings" message → END
#   1 candidate  → auto-propose the action → END (pending_action set, awaiting_confirmation)
#   2+ candidates → list them, ask user to pick → END (awaiting_booking_selection set)
#   Has booking ref in message → pass straight through to action_node

async def disambiguate_node(state: AgentState) -> dict:
    last_text = _last_human_text(state["messages"])

    # If the user gave an explicit booking reference, let Gemini handle it normally.
    if _has_booking_ref(last_text):
        return {"next_node": "action"}

    lower = last_text.lower()
    # Determine which action was intended
    if "cancel" in lower:
        action = "cancel"
    elif any(w in lower for w in ("modify", "change", "update", "reschedule")):
        action = "update"
    else:
        # Can't determine — pass to Gemini which will ask for clarification
        return {"next_node": "action"}

    # Fetch upcoming bookings (no LLM, no quota consumed)
    trip_tool = next(
        (t for t in get_tools_for_role(state["role"], state["user_id"])
         if t.name == "get_trip_history"),
        None,
    )
    if trip_tool is None:
        return {"next_node": "action"}

    history = await trip_tool.ainvoke(safe_tool_args(trip_tool, {}))
    upcoming = history.get("upcoming", [])

    # Filter: cancel only considers non-cancelled bookings; update considers all upcoming
    if action == "cancel":
        candidates = [b for b in upcoming if b.get("status") not in ("cancelled", "completed")]
    else:
        candidates = upcoming

    # --- Zero candidates ---
    # NOTE: avoid "cancelled", "confirmed", "completed" here — those words trigger
    # the supervisor's safety_check (success-keyword without a tool ToolMessage).
    if not candidates:
        action_noun = "cancellation" if action == "cancel" else "modification"
        msg = (
            f"I don't see any upcoming bookings on your account that are eligible "
            f"for {action_noun} right now. "
            "If you have a specific trip in mind, share the booking reference and "
            "I'll look into it for you."
        )
        return {"messages": [AIMessage(content=msg)], "next_node": None}

    # --- One candidate: auto-select and propose ---
    if len(candidates) == 1:
        booking = candidates[0]
        booking_id = booking.get("_id") or booking.get("id")
        route = (
            f"{booking.get('pickup_location', '?')} to "
            f"{booking.get('destination_name', booking.get('destination_city', '?'))}"
        )
        date = booking.get("departure_date", "")
        time_str = booking.get("departure_time", "")
        when = f"{date} at {time_str}" if time_str else date

        if action == "cancel":
            summary = (
                f"I'd like to cancel your trip from {route}"
                f"{' on ' + when if when else ''}. "
                "Reply **yes** to confirm or **no** to cancel."
            )
            tool_name = "cancel_booking"
        else:
            summary = (
                f"I'd like to modify your trip from {route}"
                f"{' on ' + when if when else ''}. "
                "What would you like to change?"
            )
            # For updates we still need Gemini to determine what to change
            return {
                "messages": [AIMessage(content=summary)],
                "next_node": None,
                "candidate_bookings": [booking],
                "awaiting_booking_selection": False,
            }

        return {
            "messages": [AIMessage(content=summary)],
            "pending_action": {
                "name": tool_name,
                "args": {"booking_id": booking_id},
                "summary": summary,
            },
            "awaiting_confirmation": True,
            "next_node": None,
        }

    # --- Multiple candidates: list and ask ---
    lines = [
        f"I found {len(candidates)} upcoming bookings on your account. "
        f"Which one would you like to {'cancel' if action == 'cancel' else 'modify'}?\n"
    ]
    for i, b in enumerate(candidates[:5], 1):
        route = (
            f"{b.get('pickup_location', '?')} to "
            f"{b.get('destination_name', b.get('destination_city', '?'))}"
        )
        date = b.get("departure_date", "")
        time_str = b.get("departure_time", "")
        when = f"{date} at {time_str}" if time_str else date
        lines.append(f"  {i}. {route}{' — ' + when if when else ''}")

    lines.append(
        "\nPlease reply with the number, or describe the trip "
        "(e.g. 'the Tunis to Hammamet one')."
    )

    return {
        "messages": [AIMessage(content="\n".join(lines))],
        "candidate_bookings": candidates[:5],
        "awaiting_booking_selection": True,
        "pending_selection_action": action,
        "next_node": None,
    }


def _route_disambiguate(state: AgentState) -> str:
    """Route to action if disambiguation passed through; otherwise end."""
    return "action" if state.get("next_node") == "action" else "__end__"


# ---------------------------------------------------------------------------
# Node 2c — resolve booking selection (no LLM)
# ---------------------------------------------------------------------------

async def resolve_selection_node(state: AgentState) -> dict:
    """Map the user's natural-language booking choice to a specific booking ID."""
    last_text = _last_human_text(state["messages"]).lower().strip()
    candidates = state.get("candidate_bookings") or []
    action = state.get("pending_selection_action", "cancel")

    selected = None

    # Ordinal / digit match ("1", "first", "the second one", "2nd", …)
    _ORDINALS = [
        ("1", 0), ("first", 0), ("1st", 0),
        ("2", 1), ("second", 1), ("2nd", 1),
        ("3", 2), ("third", 2), ("3rd", 2),
        ("4", 3), ("fourth", 3), ("4th", 3),
        ("5", 4), ("fifth", 4), ("5th", 4),
    ]
    words = set(re.split(r"\W+", last_text))
    for word, idx in _ORDINALS:
        if word in words and idx < len(candidates):
            selected = candidates[idx]
            break

    # Destination / route match (city name in reply)
    if selected is None:
        for b in candidates:
            dest = (b.get("destination_name") or b.get("destination_city") or "").lower()
            pickup = (b.get("pickup_location") or "").lower()
            for keyword in (dest, pickup):
                if keyword and len(keyword) > 3 and keyword in last_text:
                    selected = b
                    break
            if selected:
                break

    # Could not resolve — re-list
    if selected is None:
        lines = ["I'm not sure which booking you mean. Please pick by number:\n"]
        for i, b in enumerate(candidates, 1):
            route = (
                f"{b.get('pickup_location', '?')} to "
                f"{b.get('destination_name', b.get('destination_city', '?'))}"
            )
            date = b.get("departure_date", "")
            lines.append(f"  {i}. {route}{' — ' + date if date else ''}")
        return {"messages": [AIMessage(content="\n".join(lines))]}

    # Resolved — build confirmation
    booking_id = selected.get("_id") or selected.get("id")
    route = (
        f"{selected.get('pickup_location', '?')} to "
        f"{selected.get('destination_name', selected.get('destination_city', '?'))}"
    )
    date = selected.get("departure_date", "")
    time_str = selected.get("departure_time", "")
    when = f"{date} at {time_str}" if time_str else date

    # Modify is not a yes/no decision — there is nothing to confirm until the
    # client says WHAT to change. Gating it like a cancellation meant "yes"
    # ran update_booking with only a booking_id, changing nothing while
    # reporting success. Ask first; the next turn carries the actual edit.
    if action != "cancel":
        question = (
            f"Your trip from {route}{' on ' + when if when else ''} "
            f"(reference {booking_id}).\n\n"
            "What would you like to change? You can update the date, time, "
            "pickup address, destination, or the passenger and luggage count."
        )
        return {
            "messages": [AIMessage(content=question)],
            "pending_action": None,
            "awaiting_confirmation": False,
            "awaiting_booking_selection": False,
            "candidate_bookings": None,
            "pending_selection_action": None,
        }

    summary = (
        f"I'd like to cancel your trip from {route}"
        f"{' on ' + when if when else ''}. "
        "Reply **yes** to confirm or **no** to cancel."
    )

    return {
        "messages": [AIMessage(content=summary)],
        "pending_action": {
            "name": "cancel_booking",
            "args": {"booking_id": booking_id},
            "summary": summary,
        },
        "awaiting_confirmation": True,
        "awaiting_booking_selection": False,
        "candidate_bookings": None,
        "pending_selection_action": None,
    }


# ---------------------------------------------------------------------------
# Node 2d — action (CLOUD, state-changing tools + confirmation gate)
# ---------------------------------------------------------------------------

async def action_node(state: AgentState) -> dict:
    model = get_model()
    if model is None:
        raise RuntimeError("No cloud model available for booking actions")

    tools = [t for t in get_tools_for_role(state["role"], state["user_id"])
             if t.name in _ACTION_TOOLS]
    tool_map = {t.name: t for t in tools}
    model_with_tools = model.bind_tools(tools)
    return await run_with_confirmation(state, model_with_tools, tool_map)


# ---------------------------------------------------------------------------
# Graph assembly
# ---------------------------------------------------------------------------

def build_graph():
    g = StateGraph(AgentState)
    g.add_node("classify", classify_node)
    g.add_node("lookup", lookup_node)
    g.add_node("disambiguate", disambiguate_node)
    g.add_node("resolve_selection", resolve_selection_node)
    g.add_node("action", action_node)

    g.add_edge(START, "classify")
    g.add_conditional_edges(
        "classify",
        _route_booking,
        {
            "lookup": "lookup",
            "disambiguate": "disambiguate",
            "action": "action",
            "resolve_selection": "resolve_selection",
        },
    )
    g.add_conditional_edges(
        "disambiguate",
        _route_disambiguate,
        {"action": "action", "__end__": END},
    )
    g.add_edge("lookup", END)
    g.add_edge("resolve_selection", END)
    g.add_edge("action", END)

    return g.compile(checkpointer=MemorySaver())
