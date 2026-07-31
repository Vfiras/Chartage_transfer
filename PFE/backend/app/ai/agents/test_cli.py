"""
CLI test runner for all six AVA sub-agent graphs.

Usage:
    cd backend
    python app/ai/agents/test_cli.py --agent support
    python app/ai/agents/test_cli.py --agent all

Agents: support | loyalty | feedback | booking | operations | insights | all
"""
from __future__ import annotations

import argparse
import asyncio
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import HumanMessage

from app.core.database import connect_to_mongo, close_mongo_connection, get_database
from app.ai.agents.shared import extract_text

# ---------------------------------------------------------------------------
# Hardcoded test identities (as specified)
# ---------------------------------------------------------------------------

CLIENT_STATE = {
    "role": "client",
    "user_id": "test-client-ava-001",
    "pending_action": None,
    "awaiting_confirmation": False,
    "next_node": None,
}

ADMIN_STATE = {
    "role": "admin",
    "user_id": "test-admin-1",
    "pending_action": None,
    "awaiting_confirmation": False,
    "next_node": None,
}

# ---------------------------------------------------------------------------
# Turn runner
# ---------------------------------------------------------------------------

SEP = "=" * 62


def _truncate(text: str, n: int = 400) -> str:
    return text if len(text) <= n else text[:n] + "...(truncated)"


def _last_ai(state: dict) -> str:
    for msg in reversed(state.get("messages", [])):
        if hasattr(msg, "type") and msg.type == "ai":
            return _truncate(extract_text(msg))
    return "(no AI message)"


async def run_turn(
    agent,
    user_msg: str,
    init_state: dict,
    thread_id: str,
    turn_idx: int,
) -> tuple[str | None, Exception | None]:
    """
    Returns (ai_response_text, exception_or_None).
    On turn 0 the full init_state is merged so role/user_id/etc. are seeded.
    On subsequent turns only the new message is passed (persisted state carries
    awaiting_confirmation and pending_action forward).
    """
    config = {"configurable": {"thread_id": thread_id}}
    state_input: dict = {"messages": [HumanMessage(content=user_msg)]}
    if turn_idx == 0:
        state_input.update(init_state)

    try:
        result = await agent.ainvoke(state_input, config=config)
        return _last_ai(result), None
    except Exception as exc:
        return None, exc


async def multi_turn(
    agent,
    turns: list[str],
    init_state: dict,
    thread_id: str,
    expect_runtime_error: bool = False,
) -> bool:
    """
    Runs a scripted conversation.  Returns True if the test passed.
    """
    passed = True
    for i, user_msg in enumerate(turns):
        print(f"\n  [Turn {i+1}] User: {user_msg}")
        ai_text, err = await run_turn(agent, user_msg, init_state, thread_id, i)

        if err is not None:
            if expect_runtime_error and isinstance(err, RuntimeError) and "OPENAI_API_KEY" in str(err):
                print(f"  [Turn {i+1}] [PASS] Expected RuntimeError at turn {i+1}: {err}")
                return True  # Stop here — this is the correct outcome
            else:
                print(f"  [Turn {i+1}] [FAIL] Unexpected {type(err).__name__}: {err}")
                import traceback
                traceback.print_exc()
                return False

        print(f"  [Turn {i+1}] AVA:  {ai_text}")

    if expect_runtime_error:
        print(f"  [FAIL] Expected RuntimeError but all turns completed without one")
        return False

    return passed


# ---------------------------------------------------------------------------
# Individual agent tests
# ---------------------------------------------------------------------------

async def test_support() -> bool:
    print(f"\n{SEP}")
    print("AGENT: support")
    print(f"{SEP}")
    from app.ai.agents.support_agent import build_graph
    agent = build_graph()
    turns = [
        "What is the cancellation policy?",
        "What happens if I need to modify a booking?",
    ]
    return await multi_turn(agent, turns, CLIENT_STATE, "test-support-1")


async def test_loyalty() -> bool:
    print(f"\n{SEP}")
    print("AGENT: loyalty")
    print(f"{SEP}")
    from app.ai.agents.loyalty_agent import build_graph
    agent = build_graph()
    turns = [
        "What promos and loyalty rewards do I currently have?",
    ]
    return await multi_turn(agent, turns, CLIENT_STATE, "test-loyalty-1")


async def test_feedback() -> bool:
    print(f"\n{SEP}")
    print("AGENT: feedback  (confirmation gate: propose → confirm → execute)")
    print(f"{SEP}")
    from app.ai.agents.feedback_agent import build_graph
    agent = build_graph()
    turns = [
        "I want to file a complaint. My driver was 20 minutes late for booking booking-test-ava-001.",
        "yes",  # confirm the submit_claim action
    ]
    return await multi_turn(agent, turns, CLIENT_STATE, "test-feedback-1")


async def test_booking() -> bool:
    print(f"\n{SEP}")
    print("AGENT: booking  (lookup path live + action path → expected RuntimeError)")
    print(f"{SEP}")
    from app.ai.agents.booking_agent import build_graph

    # ── Lookup path (fully live) ──────────────────────────────────────────
    print("\n  -- Lookup path --")
    agent_lookup = build_graph()
    lookup_ok = await multi_turn(
        agent_lookup,
        ["Show me my recent trips"],
        CLIENT_STATE,
        "test-booking-lookup-1",
    )

    # ── Action path (expected: graph reaches action_node → RuntimeError) ──
    print("\n  -- Action path (RuntimeError expected at action_node) --")
    agent_action = build_graph()
    action_ok = await multi_turn(
        agent_action,
        ["I need to book a VIP car from Tunis to Hammamet next Monday at 14:00"],
        CLIENT_STATE,
        "test-booking-action-1",
        expect_runtime_error=True,
    )

    return lookup_ok and action_ok


async def test_operations() -> bool:
    print(f"\n{SEP}")
    print("AGENT: operations  (RuntimeError expected immediately — no key)")
    print(f"{SEP}")

    # Verify tool list first (graph must build cleanly)
    from app.ai.agents.operations_agent import build_graph, _TOOLS
    agent = build_graph()
    print(f"  [INFO] Graph built. Tool names configured: {sorted(_TOOLS)}")
    assert len(_TOOLS) == 5, f"Expected 5 ops tools, got {len(_TOOLS)}"
    print(f"  [PASS] Tool count == 5")

    return await multi_turn(
        agent,
        ["List all vehicles in the fleet"],
        ADMIN_STATE,
        "test-operations-1",
        expect_runtime_error=True,
    )


async def test_insights() -> bool:
    print(f"\n{SEP}")
    print("AGENT: insights  (RuntimeError expected immediately — no key)")
    print(f"{SEP}")

    from app.ai.agents.insights_agent import build_graph, _TOOLS
    agent = build_graph()
    print(f"  [INFO] Graph built. Tool names configured: {sorted(_TOOLS)}")
    assert len(_TOOLS) == 4, f"Expected 4 insights tools, got {len(_TOOLS)}"
    print(f"  [PASS] Tool count == 4")

    return await multi_turn(
        agent,
        ["Give me a dashboard overview"],
        ADMIN_STATE,
        "test-insights-1",
        expect_runtime_error=True,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

AGENT_MAP = {
    "support":    test_support,
    "loyalty":    test_loyalty,
    "feedback":   test_feedback,
    "booking":    test_booking,
    "operations": test_operations,
    "insights":   test_insights,
}


async def main() -> None:
    parser = argparse.ArgumentParser(description="AVA sub-agent CLI test runner")
    parser.add_argument(
        "--agent",
        choices=[*AGENT_MAP.keys(), "all"],
        required=True,
        help="Which agent to test",
    )
    args = parser.parse_args()

    print("Connecting to MongoDB...")
    await connect_to_mongo()

    agents_to_run = list(AGENT_MAP.keys()) if args.agent == "all" else [args.agent]
    results: dict[str, bool] = {}

    for name in agents_to_run:
        try:
            results[name] = await AGENT_MAP[name]()
        except Exception as exc:
            print(f"\n[ERROR] {name}: {type(exc).__name__}: {exc}")
            import traceback
            traceback.print_exc()
            results[name] = False

    # ── Summary ──────────────────────────────────────────────────────────
    print(f"\n{SEP}")
    print("SUMMARY")
    print(f"{SEP}")
    for name, ok in results.items():
        status = "[PASS]" if ok else "[FAIL]"
        print(f"  {status} {name}")

    await close_mongo_connection()

    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    asyncio.run(main())
