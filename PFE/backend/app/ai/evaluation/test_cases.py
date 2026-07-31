"""
AVA evaluation test suite — 28 scripted cases spanning all six agents.

Each case is a dict with:
  id                : unique case identifier
  message           : the user's first turn
  role              : 'client' | 'admin'
  user_id           : identity to seed into the supervisor state
  expected_agent    : booking | support | loyalty | feedback | operations | insights | refused
  expected_behavior : lookup | action_proposed | action_confirmed | refused
                      | rag_answer | rag_low_confidence
  follow_up         : optional second turn (e.g. 'yes' to confirm a gate proposal)
  notes             : rationale — why this case exists and what it specifically guards

Coverage:
  booking      — 5 cases (lookup, recommend_vehicle, action gate, regression guard)
  support      — 5 cases (3 KB-backed answers, 2 honest low-confidence targets)
  loyalty      — 4 cases (lookup, advice, tier)
  feedback     — 3 cases (gate propose, full round-trip, 'how do I…' regression guard)
  role-block   — 3 cases (client trying ops / insights → role_gate refuse)
  operations   — 5 cases (create propose, create confirm, status update, toggle propose,
                            toggle full round-trip)
  insights     — 3 cases (revenue lookup, overview, 'how do I…' phrasing)
"""
from __future__ import annotations

_CLIENT = "test-client-ava-001"
_ADMIN  = "test-admin-1"

TEST_CASES: list[dict] = [

    # ── BOOKING (5 cases) ────────────────────────────────────────────────────
    # 4 on the lookup path, 1 on the action/gate path (state-changing + gate).
    # booking-04 is the direct regression guard for the persona-leak bug.

    {
        "id": "booking-01",
        "message": "Show me my recent trips",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "booking", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "Core trip-history lookup. The RULE clause in _CLASSIFY_PROMPT hard-routes "
            "'my trips' → booking, so this is also a classifier robustness check."
        ),
    },
    {
        "id": "booking-02",
        "message": "What's my next upcoming trip?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "booking", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "Alternate trip-history phrasing ('my … trip') to test classifier breadth "
            "beyond the exact RULE clause wording."
        ),
    },
    {
        "id": "booking-03",
        "message": "What kind of car would you recommend for 2 passengers and 3 large bags?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "booking", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "recommend_vehicle tool path in booking's lookup_node. Tests the non-history "
            "branch of the booking agent."
        ),
    },
    {
        "id": "booking-04",
        "message": "How do I track my ride?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "booking", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "Permanent regression guard for the persona-leak bug. This exact phrasing "
            "produced developer-tutorial text containing get_trip_history, _id, user_id, "
            "and ``` before the AVA_PERSONA_PROMPT fix."
        ),
    },
    {
        "id": "booking-05",
        "message": "Please cancel my booking booking-test-ava-001",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "booking", "expected_behavior": "action_proposed",
        "follow_up": None,
        "notes": (
            "cancel_booking → booking action_node → run_with_confirmation gate proposes. "
            "Requires CLOUD_PRIMARY (Gemini); will return 'error' if no key is configured."
        ),
    },

    # ── SUPPORT / RAG (5 cases) ──────────────────────────────────────────────
    # support-01..03 expect confident KB-backed answers.
    # support-04..05 expect the agent to admit uncertainty; a confident response is
    # a FAIL here (calibration failure, not a crash) — see Known Limitations in the
    # generated report.

    {
        "id": "support-01",
        "message": "What is the cancellation policy?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "support", "expected_behavior": "rag_answer",
        "follow_up": None,
        "notes": (
            "Core KB-backed policy question. The KB should contain cancellation terms; "
            "this verifies the search_knowledge_base → synthesis path returns a confident answer."
        ),
    },
    {
        "id": "support-02",
        "message": "How do I cancel my booking?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "support", "expected_behavior": "rag_answer",
        "follow_up": None,
        "notes": (
            "Procedural cancellation phrasing. Overlaps with 'booking' vocabulary; "
            "tests that the classifier picks 'support' for policy/how-to questions "
            "rather than routing to the booking agent (Guard 3 enforces this). "
            "Updated from rag_low_confidence → rag_answer: the strengthened RAG "
            "synthesis rules (Bug 1b fix) now produce a clean KB-backed cancellation "
            "policy without unnecessary uncertainty hedges. The critical invariant is "
            "still routing (support, not booking)."
        ),
    },
    {
        "id": "support-03",
        "message": "What payment methods does Carthage Transfer accept?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "support", "expected_behavior": "rag_answer",
        "follow_up": None,
        "notes": (
            "Payment FAQ. Tests KB coverage beyond the cancellation domain and "
            "ensures the model synthesises the answer without leaking raw JSON."
        ),
    },
    {
        "id": "support-04",
        "message": "Does Carthage Transfer offer group discounts for large corporate events?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "support", "expected_behavior": "rag_low_confidence",
        "follow_up": None,
        "notes": (
            "Adjacent but unlikely to be directly in the KB. A PASS here means the model "
            "admitted uncertainty; a FAIL means it gave a confident answer with no KB "
            "evidence (hallucination risk). See Known Limitations."
        ),
    },
    {
        "id": "support-05",
        "message": "What is the maximum number of stops allowed on a single trip?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "support", "expected_behavior": "rag_low_confidence",
        "follow_up": None,
        "notes": (
            "Edge-case policy detail unlikely to be documented in the KB. A confident "
            "numeric answer (e.g. '3 stops') would be a hallucination and counts as FAIL."
        ),
    },

    # ── LOYALTY (4 cases) ────────────────────────────────────────────────────

    {
        "id": "loyalty-01",
        "message": "Do I have any promo codes available?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "loyalty", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": "Core get_user_promos lookup; direct promo-check flow.",
    },
    {
        "id": "loyalty-02",
        "message": "What loyalty rewards and points do I have?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "loyalty", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": "Rewards + tier lookup using multi-keyword phrasing ('rewards', 'points').",
    },
    {
        "id": "loyalty-03",
        "message": "How do I use a promo code?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "loyalty", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "Advice-style loyalty question. The model fetches available promos via "
            "get_user_promos, then advises in concierge voice — no gate fires."
        ),
    },
    {
        "id": "loyalty-04",
        "message": "What tier level am I on?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "loyalty", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": "Tier-status lookup; tests the 'tier' keyword routing path.",
    },

    # ── FEEDBACK (3 cases) ───────────────────────────────────────────────────
    # feedback-02 is the only client-side full round-trip in this suite.
    # feedback-03 guards the 'how do I…' regression class for the feedback agent.

    {
        "id": "feedback-01",
        "message": (
            "I want to file a complaint — my driver was 30 minutes late "
            "for booking booking-test-ava-001"
        ),
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "feedback", "expected_behavior": "action_proposed",
        "follow_up": None,
        "notes": "submit_claim gate, propose-only. Gate must fire without executing the tool.",
    },
    {
        "id": "feedback-02",
        "message": (
            "I want to file a complaint — my driver was 30 minutes late "
            "for booking booking-test-ava-001"
        ),
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "feedback", "expected_behavior": "action_confirmed",
        "follow_up": "yes",
        "notes": (
            "submit_claim full round-trip: propose (turn 1) → confirm with 'yes' (turn 2). "
            "Expects 'Done — your complaint has been submitted.' Writes a complaint record "
            "to the DB on each evaluation run."
        ),
    },
    {
        "id": "feedback-03",
        "message": "How do I file a complaint?",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "feedback", "expected_behavior": "action_proposed",
        "follow_up": None,
        "notes": (
            "Regression guard for the feedback agent's 'how do I…' behaviour. In the "
            "persona-leak test (Section 2), this phrasing triggered the gate immediately: "
            "'I'd like to submit your complaint. Reply **yes** to confirm or **no** to cancel.' "
            "A lookup response here would mean the agent changed behaviour."
        ),
    },

    # ── ROLE GATE — client → admin domain (3 cases) ──────────────────────────
    # All three expect the role_gate_node to fire and return a polite refusal
    # without dispatching to any sub-agent.

    {
        "id": "role-01",
        "message": "Change the price of the VIP car to 200 dinars",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "refused", "expected_behavior": "refused",
        "follow_up": None,
        "notes": (
            "Imperative price-change command. The admin-intent pre-check in "
            "_keyword_classify (verb 'change' + price term) classifies as 'operations'; "
            "role_gate blocks and writes an audit_log access_denied entry."
        ),
    },
    {
        "id": "role-02",
        "message": "Show me all users in the system",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "refused", "expected_behavior": "refused",
        "follow_up": None,
        "notes": (
            "Admin-only user-list query from a client. Keyword 'users list' maps to "
            "'insights' → role_gate blocks."
        ),
    },
    {
        "id": "role-03",
        "message": "Show me the analytics dashboard for all users",
        "role": "client", "user_id": _CLIENT,
        "expected_agent": "refused", "expected_behavior": "refused",
        "follow_up": None,
        "notes": (
            "Admin-only analytics request from a client. Keywords 'analytics' and "
            "'all users' route to 'insights' → role_gate blocks."
        ),
    },

    # ── OPERATIONS admin (5 cases) ───────────────────────────────────────────
    # All use CLOUD_PRIMARY (Gemini) for both classification and dispatch.
    # ops-02 and ops-05 are the two admin-side full round-trips in this suite.
    # ops-04 documents the read-only-gating gap (manage_fleet[list] going through
    # the confirmation gate and losing its result data).

    {
        "id": "ops-01",
        "message": (
            "Add a new vehicle: name Mercedes Viano, model Viano, "
            "category Van, 7 seats, 5 luggage capacity, base price 120"
        ),
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "operations", "expected_behavior": "action_proposed",
        "follow_up": None,
        "notes": "manage_fleet[create] gate, propose-only turn.",
    },
    {
        "id": "ops-02",
        "message": (
            "Add a new vehicle: name Mercedes Viano, model Viano, "
            "category Van, 7 seats, 5 luggage capacity, base price 120"
        ),
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "operations", "expected_behavior": "action_confirmed",
        "follow_up": "yes",
        "notes": (
            "manage_fleet[create] full round-trip. Writes a new vehicle record on each "
            "evaluation run (no uniqueness constraint on name). Second run creates a "
            "duplicate — expected and acceptable for a test harness."
        ),
    },
    {
        "id": "ops-03",
        "message": "Update the status of booking booking-test-ava-001 to confirmed",
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "operations", "expected_behavior": "action_proposed",
        "follow_up": None,
        "notes": "update_booking_status gate, propose-only.",
    },
    {
        "id": "ops-04",
        "message": "Show me the current vehicle fleet list",
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "operations", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "Read-only-gating FIX (PROJECT_CONTEXT.md §19, fixed June 2026): "
            "manage_fleet[list] is read-only, so operations_agent now executes it and "
            "synthesises the fleet data immediately (the insights_agent pattern) instead "
            "of routing it through the confirmation gate. Expected behaviour is therefore "
            "'lookup' (data shown), NOT 'action_proposed'. Was 'action_proposed' while the "
            "gate-everything gap existed; updated after the fix landed and was verified to "
            "return the actual fleet (Standard/VIP/Luxury/Van) with no confirm prompt."
        ),
    },
    {
        "id": "ops-05",
        "message": "Toggle the active status of the promotion with id promo-vip15",
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "operations", "expected_behavior": "action_confirmed",
        "follow_up": "yes",
        "notes": (
            "manage_promotions[toggle] full round-trip. Flips promo-vip15's active flag. "
            "Run 1 flips in one direction; run 2 flips it back — both are 'action_confirmed'. "
            "The PROPOSE text differs between runs (inactive→active vs active→inactive) but "
            "the behavior category is the same. The promo ends up at its original state "
            "after both runs complete."
        ),
    },

    # ── INSIGHTS admin (3 cases) ─────────────────────────────────────────────
    # All use CLOUD_PRIMARY (Gemini). No gate in insights_agent — data is
    # returned directly after tool execution.

    {
        "id": "insights-01",
        "message": "Show me the revenue dashboard",
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "insights", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": "get_dashboard_analytics lookup; core revenue view.",
    },
    {
        "id": "insights-02",
        "message": "Give me an overview of all bookings",
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "insights", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": "get_admin_overview or list_all_bookings lookup.",
    },
    {
        "id": "insights-03",
        "message": "How do I see the analytics?",
        "role": "admin", "user_id": _ADMIN,
        "expected_agent": "insights", "expected_behavior": "lookup",
        "follow_up": None,
        "notes": (
            "Admin 'how do I…' phrasing for insights. The persona-leak test (Section 2) "
            "showed Gemini calls get_dashboard_analytics and returns real data ('Your total "
            "revenue is $154') rather than giving procedural instructions — so expected "
            "behavior is 'lookup', not a conversational reply."
        ),
    },
]
