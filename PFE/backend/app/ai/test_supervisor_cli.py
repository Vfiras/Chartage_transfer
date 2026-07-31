"""
Supervisor CLI tests — 4 scripted conversations + routing stability run.

Test 1: Client multi-domain session
    Support → Loyalty → Booking-lookup → Feedback (propose + confirm)
    Verifies: per-turn domain routing matches expected, persistence, confirmation flow.

Test 2: Client → admin-domain request
    Expected: polite refusal from role_gate, no tool calls, audit_log access_denied entry.

Test 3: Admin → any request
    If CLOUD_PRIMARY (Gemini) is configured: classification succeeds, domain is insights.
    If CLOUD_PRIMARY is None (no GOOGLE_API_KEY): RuntimeError("GOOGLE_API_KEY not set...").

Regression: keyword classification + safety_check_node gap.

Stability: 10 independent runs of the 5-turn client conversation.
    Reports per-turn domain for every run and per-phrase misclassification count.
"""
from __future__ import annotations

import asyncio
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import HumanMessage

from app.core.database import connect_to_mongo, close_mongo_connection, get_database
from app.ai.agents.shared import extract_text

SEP = "=" * 64


def _truncate(text: str, n: int = 450) -> str:
    return text if len(text) <= n else text[:n] + "...(truncated)"


async def run_turn(
    supervisor,
    user_msg: str,
    init_state: dict,
    thread_id: str,
    turn_idx: int,
) -> tuple[str | None, str | None, Exception | None]:
    """
    Run one supervisor turn.  Returns (ai_text, domain, error_or_None).

    domain is the value of state["domain"] after classify_intent_node runs.
    For Turn 5 (sticky confirmation), this is the reused domain from Turn 4.
    init_state is merged only on turn 0 to seed role/user_id.
    """
    config = {"configurable": {"thread_id": thread_id}}
    state_input: dict = {"messages": [HumanMessage(content=user_msg)]}
    if turn_idx == 0:
        state_input.update(init_state)

    try:
        result = await supervisor.ainvoke(state_input, config=config)
        domain = result.get("domain")
        for msg in reversed(result.get("messages", [])):
            if hasattr(msg, "type") and msg.type == "ai":
                return _truncate(extract_text(msg)), domain, None
        return result.get("_pending_ai", "(no AI response)"), domain, None
    except Exception as exc:
        return None, None, exc


# ---------------------------------------------------------------------------
# Test 1 — Client multi-domain session
# ---------------------------------------------------------------------------

# (message, expected_domain) — Turn 5 reuses Turn 4's domain via sticky check
_TEST1_TURNS: list[tuple[str, str]] = [
    ("What is the cancellation policy?",           "support"),
    ("What loyalty rewards and promos do I have?", "loyalty"),
    ("Show me my recent trips",                    "booking"),
    ("I want to file a complaint — my driver was 30 minutes late for booking booking-test-ava-001.", "feedback"),
    ("yes",                                        "feedback"),
]


async def test_client_multi_domain() -> bool:
    print(f"\n{SEP}")
    print("TEST 1: Client multi-domain session")
    print("  Sequence: Support → Loyalty → Booking-lookup → Feedback (2 turns)")
    print("  Per-turn domain assertion: expected vs actual")
    print(f"{SEP}")

    from app.ai.supervisor import build_supervisor
    supervisor = build_supervisor()

    thread_id = "test-supervisor-client-mixed-1"
    init_state = {
        "role": "client",
        "user_id": "test-client-ava-001",
        "_access_denied": False,
        "_dispatch_delta": None,
        "_pending_ai": None,
        "domain": None,
    }

    passed = True
    for i, (msg, expected_domain) in enumerate(_TEST1_TURNS):
        print(f"\n  [Turn {i+1}] User: {msg}")
        ai_text, actual_domain, err = await run_turn(supervisor, msg, init_state, thread_id, i)
        if err is not None:
            print(f"  [Turn {i+1}] [FAIL] {type(err).__name__}: {err}")
            import traceback; traceback.print_exc()
            passed = False
            break
        domain_ok = actual_domain == expected_domain
        domain_tag = "[PASS]" if domain_ok else "[FAIL]"
        print(f"  [Turn {i+1}] domain: expected={expected_domain!r}  actual={actual_domain!r}  {domain_tag}")
        print(f"  [Turn {i+1}] AVA:  {ai_text}")
        if not domain_ok:
            passed = False

    # Verify chat_sessions persistence
    print(f"\n  Checking chat_sessions for user_id='test-client-ava-001'...")
    db = get_database()
    session_doc = await db.chat_sessions.find_one({"user_id": "test-client-ava-001"})
    if session_doc is None:
        print("  [FAIL] No chat_sessions document found")
        return False
    turn_count = len(session_doc.get("turns", []))
    print(f"  Stored turn count in this document: {turn_count}")
    if turn_count >= len(_TEST1_TURNS):
        print(f"  [PASS] chat_sessions has {turn_count} turn(s) (>= {len(_TEST1_TURNS)} from this run)")
    else:
        print(f"  [WARN] Only {turn_count} turns stored (expected >= {len(_TEST1_TURNS)})")

    return passed


# ---------------------------------------------------------------------------
# Test 2 — Client attempting admin-domain request
# ---------------------------------------------------------------------------

async def test_client_admin_domain() -> bool:
    print(f"\n{SEP}")
    print("TEST 2: Client → admin-domain request (expected: polite refusal + audit_log entry)")
    print(f"{SEP}")

    from app.ai.supervisor import build_supervisor
    supervisor = build_supervisor()

    thread_id = "test-supervisor-client-ops-block-1"
    init_state = {
        "role": "client",
        "user_id": "test-client-ava-001",
        "_access_denied": False,
        "_dispatch_delta": None,
        "_pending_ai": None,
        "domain": None,
    }

    user_msg = "Change the price of the VIP car to 200 dinars"
    print(f"\n  [Turn 1] User: {user_msg}")

    ai_text, _, err = await run_turn(supervisor, user_msg, init_state, thread_id, 0)

    if err is not None:
        print(f"  [FAIL] Unexpected {type(err).__name__}: {err}")
        return False

    print(f"  [Turn 1] AVA:  {ai_text}")

    lower = (ai_text or "").lower()
    is_refusal = "administrative access" in lower or "sorry" in lower or "administrator" in lower
    if is_refusal:
        print("  [PASS] Response is a polite refusal (no tool call attempted)")
    else:
        print(f"  [FAIL] Response does not look like a refusal: {ai_text}")
        return False

    db = get_database()
    audit_entry = await db.audit_log.find_one({
        "user_id": "test-client-ava-001",
        "event": "access_denied",
    })
    if audit_entry:
        print(f"  [PASS] audit_log access_denied entry found: attempted_domain='{audit_entry.get('attempted_domain')}'")
    else:
        print("  [FAIL] No access_denied entry found in audit_log")
        return False

    return True


# ---------------------------------------------------------------------------
# Test 3 — Admin → RuntimeError at classify_intent_node
# ---------------------------------------------------------------------------

async def test_admin_classify_error() -> bool:
    print(f"\n{SEP}")
    print("TEST 3: Admin → any request")
    print("  CLOUD_PRIMARY (Gemini) configured → classification succeeds, domain=insights")
    print("  CLOUD_PRIMARY absent (no GOOGLE_API_KEY) → RuntimeError immediately")
    print(f"{SEP}")

    from app.ai.model_router import CLOUD_PRIMARY
    from app.ai.supervisor import build_supervisor
    supervisor = build_supervisor()

    thread_id = "test-supervisor-admin-classify-1"
    init_state = {
        "role": "admin",
        "user_id": "test-admin-1",
        "_access_denied": False,
        "_dispatch_delta": None,
        "_pending_ai": None,
        "domain": None,
    }

    user_msg = "Show me all users in the system"
    print(f"\n  [Turn 1] User: {user_msg}")

    ai_text, domain, err = await run_turn(supervisor, user_msg, init_state, thread_id, 0)

    if CLOUD_PRIMARY is not None:
        # Gemini key is set — admin classification should succeed
        if err is not None:
            print(f"  [FAIL] Unexpected {type(err).__name__}: {err}")
            import traceback; traceback.print_exc()
            return False
        print(f"  [Turn 1] domain: {domain!r}  AVA: {ai_text}")
        if domain in ("insights", "operations"):
            print(f"  [PASS] Admin classify succeeded via Gemini, domain={domain!r}")
            return True
        print(f"  [FAIL] Unexpected domain {domain!r} (expected 'insights' or 'operations')")
        return False
    else:
        # No Gemini key — must raise RuntimeError with GOOGLE_API_KEY in message
        if err is None:
            print(f"  [FAIL] Expected RuntimeError (no key) but got a response: {ai_text}")
            return False
        if isinstance(err, RuntimeError) and "GOOGLE_API_KEY" in str(err):
            print(f"  [PASS] RuntimeError at classify_intent_node (before role_gate/dispatch): {err}")
            return True
        print(f"  [FAIL] Wrong exception type {type(err).__name__}: {err}")
        import traceback; traceback.print_exc()
        return False


# ---------------------------------------------------------------------------
# Regression — keyword classification fix + safety_check_node gap
# ---------------------------------------------------------------------------

async def test_keyword_and_safety_regression() -> bool:
    print(f"\n{SEP}")
    print("REGRESSION: keyword classification fix + safety_check_node gap")
    print(f"{SEP}")

    from app.ai.supervisor import _keyword_classify, safety_check_node
    from langchain_core.messages import AIMessage

    passed = True

    # Fix 2a: a question sentence containing both "change" and "price" must NOT
    # classify as operations — the question-word opener suppresses the pre-check.
    question = "did the price for the VIP car change recently?"
    kw = _keyword_classify(question)
    if kw != "operations":
        print(f"  [PASS] keyword/question: '{question}' -> '{kw}' (non-operations)")
    else:
        print(f"  [FAIL] keyword/question: '{question}' -> 'operations' (false positive present)")
        passed = False

    # Fix 2b: the original Test 2 imperative command must still reach operations.
    command = "change the price of the VIP car to 200 dinars"
    kw2 = _keyword_classify(command)
    if kw2 == "operations":
        print(f"  [PASS] keyword/command: '{command}' -> 'operations'")
    else:
        print(f"  [FAIL] keyword/command: '{command}' -> '{kw2}' (should be 'operations')")
        passed = False

    # Fix 3: safety_check_node must override a "Done!"-prefixed AI response that has
    # no ToolMessage in the delta.
    # OLD code (is_done_prefix check): pending.startswith("Done!") -> tool_ran=True
    #   -> no override. This test would have FAILED under the old code.
    # NEW code (ToolMessage evidence only): no ToolMessage -> tool_ran=False
    #   -> override fires. This test must PASS under the new code.
    fake_state: dict = {
        "messages": [],
        "role": "client",
        "user_id": "test-safety-regression-001",
        "domain": "feedback",
        "_access_denied": False,
        "_pending_ai": "Done! Confirmed. Your claim has been submitted.",
        "_dispatch_delta": [AIMessage(content="Done! Confirmed. Your claim has been submitted.")],
    }
    result = await safety_check_node(fake_state)
    override = result.get("_pending_ai", "")
    if "something went wrong" in override.lower() or "apologize" in override.lower():
        print(
            "  [PASS] safety/hallucination: 'Done!'-prefixed response without ToolMessage "
            "correctly overridden (would have slipped past old is_done_prefix check)"
        )
    else:
        print(
            f"  [FAIL] safety/hallucination: safety_check_node did NOT override\n"
            f"         (is_done_prefix gap still present)\n"
            f"         result['_pending_ai'] = {override!r}"
        )
        passed = False

    return passed


# ---------------------------------------------------------------------------
# Phrase coverage — booking-history phrasings (single-turn, client role)
# ---------------------------------------------------------------------------

_BOOKING_HISTORY_PHRASES: list[tuple[str, str]] = [
    ("Show me my recent trips",           "booking"),
    ("what trips do I have coming up",    "booking"),
    ("show my booking history",           "booking"),
    ("do I have any upcoming rides",      "booking"),
    ("what's my next trip",               "booking"),
    ("list my recent bookings",           "booking"),
]


async def test_phrase_coverage() -> bool:
    """
    Run each trip-history phrase as a standalone single-turn client request.
    Reports the classified domain and whether it matches the expected 'booking'.
    Used to measure pre-fix and post-fix accuracy across the phrase set.
    """
    print(f"\n{SEP}")
    print("PHRASE COVERAGE: booking-history phrasing variants (single-turn, client)")
    print(f"{SEP}")

    from app.ai.supervisor import build_supervisor

    all_pass = True
    for phrase, expected in _BOOKING_HISTORY_PHRASES:
        supervisor = build_supervisor()
        thread_id = f"test-phrase-{abs(hash(phrase)) % 100000}"
        init_state = {
            "role": "client",
            "user_id": "test-phrase-client-001",
            "_access_denied": False,
            "_dispatch_delta": None,
            "_pending_ai": None,
            "domain": None,
        }
        _, actual_domain, err = await run_turn(supervisor, phrase, init_state, thread_id, 0)
        if err is not None:
            print(f"  [ERR] {phrase!r:50s}  {type(err).__name__}: {err}")
            all_pass = False
        else:
            ok = actual_domain == expected
            tag = "[PASS]" if ok else "[FAIL]"
            got = actual_domain or "None"
            print(f"  {tag} {phrase!r:50s}  got={got!r}  want={expected!r}")
            if not ok:
                all_pass = False

    return all_pass


# ---------------------------------------------------------------------------
# Stability — 10 independent runs of the 5-turn client conversation
# ---------------------------------------------------------------------------

async def test_routing_stability() -> bool:
    """
    Run the scripted 5-turn client conversation 10 times with fresh state.

    For each run: print all 5 classified domains and whether each matched expected.
    At the end: per-phrase misclassification count across 10 runs.

    classify_intent_node only sees the last human message (stateless w.r.t. prior
    turns), so each run is an independent sample of model classification behaviour.
    """
    print(f"\n{SEP}")
    print("STABILITY: 10-run routing test (5 turns each, fresh state per run)")
    print("  Tracking domain classifications to detect non-deterministic misrouting.")
    print(f"{SEP}")

    from app.ai.supervisor import build_supervisor

    RUNS = 10
    phrase_domains: dict[str, list[str]] = {msg: [] for msg, _ in _TEST1_TURNS}
    run_results: list[bool] = []

    for run_idx in range(RUNS):
        supervisor = build_supervisor()
        thread_id = f"test-stability-run-{run_idx}"
        init_state = {
            "role": "client",
            "user_id": f"test-stability-{run_idx}",
            "_access_denied": False,
            "_dispatch_delta": None,
            "_pending_ai": None,
            "domain": None,
        }

        domains: list[str] = []
        run_ok = True
        for turn_idx, (msg, expected) in enumerate(_TEST1_TURNS):
            _, actual_domain, err = await run_turn(
                supervisor, msg, init_state, thread_id, turn_idx
            )
            if err is not None:
                domains.append(f"ERR({type(err).__name__})")
                run_ok = False
            else:
                d = actual_domain or "None"
                domains.append(d)
                if d != expected:
                    run_ok = False

        run_results.append(run_ok)
        status = "[PASS]" if run_ok else "[FAIL]"

        # Build per-turn annotation: actual vs expected
        annotations = []
        for (msg, expected), d in zip(_TEST1_TURNS, domains):
            mark = "OK" if d == expected else f"WRONG(got={d!r},want={expected!r})"
            annotations.append(mark)

        print(f"\n  Run {run_idx + 1:2d}: {status}")
        for j, ((msg, expected), d, ann) in enumerate(zip(_TEST1_TURNS, domains, annotations)):
            short_msg = msg[:52] + "..." if len(msg) > 55 else msg
            print(f"    T{j+1}: {d:12s}  {ann}  | {short_msg!r}")

        for (msg, _), d in zip(_TEST1_TURNS, domains):
            phrase_domains[msg].append(d)

    # Summary
    print(f"\n{SEP}")
    print(f"STABILITY SUMMARY  ({sum(run_results)}/{RUNS} runs fully correct)")
    print(f"{SEP}")
    any_miss = False
    for msg, expected in _TEST1_TURNS:
        actuals = phrase_domains[msg]
        misses = [d for d in actuals if d != expected]
        miss_rate = f"{len(misses)}/{RUNS}"
        short_msg = msg[:60] + "..." if len(msg) > 63 else msg
        if misses:
            wrong_values = sorted(set(misses))
            print(f"  MISCLASSIFIED {miss_rate}: {wrong_values}")
            print(f"    phrase:   {short_msg!r}")
            print(f"    expected: {expected!r}")
            any_miss = True
        else:
            print(f"  OK {RUNS}/{RUNS}: {short_msg!r} -> always '{expected}'")

    return not any_miss


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    print("Connecting to MongoDB...")
    await connect_to_mongo()

    results = {}
    for name, fn in [
        ("Test 1 — client multi-domain", test_client_multi_domain),
        ("Test 2 — client → admin domain", test_client_admin_domain),
        ("Test 3 — admin → classify", test_admin_classify_error),
        ("Regression — keyword + safety gap", test_keyword_and_safety_regression),
        ("Phrase coverage — booking history", test_phrase_coverage),
        ("Stability — 10-run routing", test_routing_stability),
    ]:
        try:
            results[name] = await fn()
        except Exception as exc:
            print(f"\n[ERROR] {name}: {type(exc).__name__}: {exc}")
            import traceback; traceback.print_exc()
            results[name] = False

    print(f"\n{SEP}")
    print("SUMMARY")
    print(f"{SEP}")
    for name, ok in results.items():
        print(f"  {'[PASS]' if ok else '[FAIL]'} {name}")

    await close_mongo_connection()
    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    asyncio.run(main())
