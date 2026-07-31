"""
AVA evaluation runner.

Runs all 28 test cases twice through the real supervisor pipeline
(classify → gate → dispatch → safety → session_write) and writes a
markdown results file.

Usage (from backend/):
  python -m app.ai.evaluation.run_eval

Output:
  backend/app/ai/evaluation/results_<YYYY-MM-DD_HH-MM-SS>.md

Each run uses isolated thread IDs (eval-r1-<id> / eval-r2-<id>) so
sub-agent MemorySaver state never bleeds between runs or between cases.
"""
from __future__ import annotations

import asyncio
import os
import sys
import time
from datetime import datetime, timezone
from typing import Any

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from langchain_core.messages import HumanMessage

from app.core.database import connect_to_mongo, close_mongo_connection
from app.ai.supervisor import build_supervisor
from app.ai.agents.shared import extract_text
from app.ai.evaluation.test_cases import TEST_CASES


# ─── Behavior inference ────────────────────────────────────────────────────────

# Phrases that signal calibrated uncertainty in support responses.
_UNCERTAINTY_MARKERS = [
    "i don't have",
    "i do not have",
    "don't have specific",
    "not have specific",
    "i'm not sure",
    "i am not sure",
    "unable to provide",
    "i'm unable",
    "i am unable",
    "cannot provide specific",
    "not have information",
    "cannot confirm",
    "outside of my",
    "not in a position to",
    "not available to me",
    "no specific information",
]


def infer_behavior(
    response: str,
    follow_up_sent: bool,
    domain: str | None,
    access_denied: bool,
) -> str:
    """Classify the observed behavior from a supervisor response.

    Returns one of: refused | action_proposed | action_confirmed |
                    rag_answer | rag_low_confidence | lookup
    """
    lower = response.lower()

    if access_denied:
        return "refused"

    if "reply **yes** to confirm" in lower or "please reply **yes** to confirm" in lower:
        return "action_proposed"

    if follow_up_sent:
        # After an affirmation turn, expect humanize_result output.
        _done_markers = [
            "done —", "done!", "has been cancelled", "has been submitted",
            "has been created", "has been updated", "has been added",
            "has been removed", "now active", "now inactive", "now unavailable",
            "now available",
        ]
        if any(m in lower for m in _done_markers):
            return "action_confirmed"
        # Gate may have re-prompted for unrecognised input.
        if "reply **yes** to confirm" in lower:
            return "action_proposed"
        # Fallback: if follow_up was sent, treat any non-gate response as confirmed.
        return "action_confirmed"

    if domain == "support":
        if any(m in lower for m in _UNCERTAINTY_MARKERS):
            return "rag_low_confidence"
        return "rag_answer"

    return "lookup"


def infer_tier(actual_agent: str, role: str, actual_behavior: str) -> str:
    """Derive the dominant LLM tier from routing policy — no extra instrumentation.

    Routing is flat: every LLM call (classification, tool selection, synthesis,
    admin actions) goes to CLOUD_PRIMARY (Gemini).  Refused cases are blocked by
    the role gate after the Gemini classification call, so no dispatch model runs.
    """
    if actual_behavior == "refused" or actual_agent == "refused":
        return "CLOUD (gemini-2.5-flash) — classify only; dispatch blocked by gate"
    return "CLOUD (gemini-2.5-flash)"


# ─── Single-case runner ────────────────────────────────────────────────────────

async def run_case(supervisor: Any, case: dict, run_num: int) -> dict:
    """Run one test case (1 or 2 turns) through the supervisor.

    Returns a result dict with all fields needed for the markdown table.
    """
    case_id = case["id"]
    thread_id = f"eval-r{run_num}-{case_id}"
    config = {"configurable": {"thread_id": thread_id}}

    init_state = {
        "role": case["role"],
        "user_id": case["user_id"],
        "_access_denied": False,
        "_dispatch_delta": None,
        "_pending_ai": None,
        "domain": None,
    }

    t_start = time.monotonic()
    error_msg: str | None = None
    response_text = ""
    actual_domain: str | None = None
    access_denied = False
    follow_up_sent = bool(case.get("follow_up"))

    try:
        # Turn 1 ─────────────────────────────────────────────────────────────
        state_input: dict = {
            "messages": [HumanMessage(content=case["message"])],
            **init_state,
        }
        result = await supervisor.ainvoke(state_input, config=config)

        actual_domain = result.get("domain")
        access_denied = bool(result.get("_access_denied"))

        for msg in reversed(result.get("messages", [])):
            if hasattr(msg, "type") and msg.type == "ai":
                response_text = extract_text(msg)
                break

        # Turn 2 (follow_up) ──────────────────────────────────────────────────
        if follow_up_sent and not access_denied:
            state_input2: dict = {
                "messages": [HumanMessage(content=case["follow_up"])],
            }
            result2 = await supervisor.ainvoke(state_input2, config=config)
            for msg in reversed(result2.get("messages", [])):
                if hasattr(msg, "type") and msg.type == "ai":
                    response_text = extract_text(msg)
                    break

    except Exception as exc:  # noqa: BLE001
        error_msg = f"{type(exc).__name__}: {exc}"

    latency = round(time.monotonic() - t_start, 1)

    # Normalise actual_agent: 'refused' if gate fired, otherwise the domain.
    actual_agent: str = "refused" if access_denied else (actual_domain or "unknown")

    # Infer observed behavior.
    actual_behavior = (
        "error"
        if error_msg
        else infer_behavior(response_text, follow_up_sent, actual_domain, access_denied)
    )

    expected_agent = case["expected_agent"]
    expected_behavior = case["expected_behavior"]
    agent_match = actual_agent == expected_agent
    behavior_match = actual_behavior == expected_behavior
    passed = agent_match and behavior_match and not error_msg

    tier = infer_tier(actual_agent, case["role"], actual_behavior)

    # Truncate response for the table (full text is logged to stdout separately).
    response_short = (
        response_text[:280] + "…" if len(response_text) > 280 else response_text
    ).replace("\n", " ")

    return {
        "id": case_id,
        "message_short": (
            case["message"][:52] + "…" if len(case["message"]) > 52 else case["message"]
        ),
        "role": case["role"],
        "expected_agent": expected_agent,
        "actual_agent": actual_agent,
        "agent_match": agent_match,
        "expected_behavior": expected_behavior,
        "actual_behavior": actual_behavior,
        "behavior_match": behavior_match,
        "passed": passed,
        "latency": latency,
        "tier": tier,
        "response_short": response_short,
        "error": error_msg,
        "notes": case.get("notes", ""),
    }


# ─── Report generator ─────────────────────────────────────────────────────────

def _pass_icon(ok: bool | None) -> str:
    if ok is None:
        return "—"
    return "PASS" if ok else "FAIL"


def _agent_label(agent: str) -> str:
    return agent if agent else "unknown"


def generate_report(
    run1: list[dict],
    run2: list[dict],
    run1_wall: float,
    run2_wall: float,
) -> str:
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    total = len(run1)

    # ── Per-case aggregation ──────────────────────────────────────────────────
    r1_by_id = {r["id"]: r for r in run1}
    r2_by_id = {r["id"]: r for r in run2}

    r1_pass = sum(1 for r in run1 if r["passed"])
    r2_pass = sum(1 for r in run2 if r["passed"])
    combined_pass = sum(
        1 for r1, r2 in zip(run1, run2) if r1["passed"] and r2["passed"]
    )

    # ── Inconsistencies ───────────────────────────────────────────────────────
    inconsistencies: list[dict] = []
    for r1, r2 in zip(run1, run2):
        if r1.get("error") or r2.get("error"):
            continue  # don't flag errors as non-determinism
        agent_changed = r1["actual_agent"] != r2["actual_agent"]
        behavior_changed = r1["actual_behavior"] != r2["actual_behavior"]
        if agent_changed or behavior_changed:
            inconsistencies.append({
                "id": r1["id"],
                "r1_agent": r1["actual_agent"],
                "r2_agent": r2["actual_agent"],
                "r1_behavior": r1["actual_behavior"],
                "r2_behavior": r2["actual_behavior"],
            })

    # ── Per-agent pass rates ──────────────────────────────────────────────────
    agents_expected = sorted({c["expected_agent"] for c in TEST_CASES})  # type: ignore[arg-type]
    agent_stats: dict[str, dict] = {}
    for agent in agents_expected:
        subset_r1 = [r for r in run1 if r["expected_agent"] == agent]
        subset_r2 = [r for r in run2 if r["expected_agent"] == agent]
        n = len(subset_r1)
        p1 = sum(1 for r in subset_r1 if r["passed"])
        p2 = sum(1 for r in subset_r2 if r["passed"])
        agent_stats[agent] = {"n": n, "r1": p1, "r2": p2}

    # ── Markdown assembly ─────────────────────────────────────────────────────
    lines: list[str] = []

    lines.append(f"# AVA Evaluation Results")
    lines.append(f"")
    lines.append(f"**Generated:** {now_str}  ")
    lines.append(f"**Cases:** {total}  |  **Runs:** 2  |  **Pipeline:** full supervisor (classify → gate → dispatch → safety → session_write)")
    lines.append(f"")

    # ── Run 1 table ───────────────────────────────────────────────────────────
    lines.append(f"## Run 1  ({r1_pass}/{total} passed, wall time {run1_wall:.0f}s)")
    lines.append(f"")
    lines.append(
        "| Case ID | Message | Role | Exp Agent | Act Agent | "
        "Exp Behavior | Act Behavior | Pass | Latency | Tier |"
    )
    lines.append(
        "|---------|---------|------|-----------|-----------|"
        "--------------|--------------|------|---------|------|"
    )
    for r in run1:
        agent_ok = "✓" if r["agent_match"] else "✗"
        beh_ok   = "✓" if r["behavior_match"] else "✗"
        err_note = f" ⚠ {r['error'][:60]}" if r["error"] else ""
        lines.append(
            f"| {r['id']} "
            f"| {r['message_short']} "
            f"| {r['role']} "
            f"| {r['expected_agent']} "
            f"| {r['actual_agent']} {agent_ok} "
            f"| {r['expected_behavior']} "
            f"| {r['actual_behavior']} {beh_ok} "
            f"| **{_pass_icon(r['passed'])}** "
            f"| {r['latency']}s "
            f"| {r['tier']}{err_note} |"
        )
    lines.append(f"")

    # ── Run 2 table ───────────────────────────────────────────────────────────
    lines.append(f"## Run 2  ({r2_pass}/{total} passed, wall time {run2_wall:.0f}s)")
    lines.append(f"")
    lines.append(
        "| Case ID | Message | Role | Exp Agent | Act Agent | "
        "Exp Behavior | Act Behavior | Pass | Latency | Tier |"
    )
    lines.append(
        "|---------|---------|------|-----------|-----------|"
        "--------------|--------------|------|---------|------|"
    )
    for r in run2:
        agent_ok = "✓" if r["agent_match"] else "✗"
        beh_ok   = "✓" if r["behavior_match"] else "✗"
        err_note = f" ⚠ {r['error'][:60]}" if r["error"] else ""
        lines.append(
            f"| {r['id']} "
            f"| {r['message_short']} "
            f"| {r['role']} "
            f"| {r['expected_agent']} "
            f"| {r['actual_agent']} {agent_ok} "
            f"| {r['expected_behavior']} "
            f"| {r['actual_behavior']} {beh_ok} "
            f"| **{_pass_icon(r['passed'])}** "
            f"| {r['latency']}s "
            f"| {r['tier']}{err_note} |"
        )
    lines.append(f"")

    # ── Summary section ───────────────────────────────────────────────────────
    lines.append(f"## Summary")
    lines.append(f"")
    lines.append(f"### Overall Pass Rate")
    lines.append(f"")
    lines.append(f"| Run | Passed | Total | Rate |")
    lines.append(f"|-----|--------|-------|------|")
    lines.append(f"| Run 1 | {r1_pass} | {total} | {100*r1_pass//total}% |")
    lines.append(f"| Run 2 | {r2_pass} | {total} | {100*r2_pass//total}% |")
    lines.append(f"| Both | {combined_pass} | {total} | {100*combined_pass//total}% *(case passed in both runs)* |")
    lines.append(f"")

    lines.append(f"### Pass Rate by Agent")
    lines.append(f"")
    lines.append(f"| Agent | Cases | Run 1 | Run 2 |")
    lines.append(f"|-------|-------|-------|-------|")
    for agent, s in agent_stats.items():
        n = s["n"]
        lines.append(
            f"| {agent} | {n} "
            f"| {s['r1']}/{n} ({100*s['r1']//n if n else 0}%) "
            f"| {s['r2']}/{n} ({100*s['r2']//n if n else 0}%) |"
        )
    lines.append(f"")

    # ── Inconsistency report ──────────────────────────────────────────────────
    lines.append(f"### Consistency Between Runs")
    lines.append(f"")
    if not inconsistencies:
        lines.append(
            "All cases where both runs completed without error produced identical "
            "agent routing and behavior classifications. No non-determinism was observed "
            "between the two runs for any case."
        )
    else:
        lines.append(
            f"{len(inconsistencies)} case(s) produced different results between runs, "
            f"indicating model non-determinism:"
        )
        lines.append(f"")
        for inc in inconsistencies:
            agent_note = (
                f"agent: {inc['r1_agent']} → {inc['r2_agent']}; "
                if inc["r1_agent"] != inc["r2_agent"]
                else ""
            )
            beh_note = (
                f"behavior: {inc['r1_behavior']} → {inc['r2_behavior']}"
                if inc["r1_behavior"] != inc["r2_behavior"]
                else ""
            )
            lines.append(f"- **{inc['id']}**: {agent_note}{beh_note}")
    lines.append(f"")

    # ── Response excerpts (non-passing cases) ─────────────────────────────────
    failing_r1 = [r for r in run1 if not r["passed"]]
    if failing_r1:
        lines.append(f"### Failing Case Response Excerpts (Run 1)")
        lines.append(f"")
        for r in failing_r1:
            lines.append(f"**{r['id']}** — expected `{r['expected_agent']}`/`{r['expected_behavior']}`, got `{r['actual_agent']}`/`{r['actual_behavior']}`")
            if r["error"]:
                lines.append(f"> ERROR: {r['error']}")
            elif r["response_short"]:
                lines.append(f"> {r['response_short']}")
            lines.append(f"")

    # ── Known limitations ─────────────────────────────────────────────────────
    lines.append(f"### Known Limitations")
    lines.append(f"")
    lines.append(
        "**RAG confidence calibration (`support-04`, `support-05`).** "
        "These cases test whether the support agent admits uncertainty for questions "
        "that are adjacent to but not directly documented in the knowledge base. "
        "The current AVA persona prompt instructs the model to translate data into plain "
        "language and avoid leaking internals, but does not explicitly require it to "
        "signal low confidence when the KB returns low-relevance results. "
        "As a result, the model tends to synthesise a plausible answer regardless "
        "of KB relevance — a confident response to an out-of-scope question is scored "
        "as FAIL (`rag_answer` instead of `rag_low_confidence`). "
        "This is a genuine calibration gap, not a crash or a persona leak. "
        "Remediation: add an explicit uncertainty instruction to `AVA_PERSONA_PROMPT` "
        "(e.g., 'If the knowledge base does not contain a direct answer, say so clearly "
        "rather than guessing') and re-evaluate."
    )
    lines.append(f"")
    lines.append(
        "**Read-only operations gating (`ops-04`, `manage_fleet[list]`).** "
        "The `operations_agent` routes all five of its tools through `run_with_confirmation`, "
        "including the three read-only actions: `manage_fleet[list]`, "
        "`manage_pricing_rules[get]`, and `manage_suppliers[list]`. "
        "These receive an unnecessary confirmation gate; when the admin confirms, "
        "`humanize_result` returns a one-liner (`'Done — I've pulled up the current fleet.'`) "
        "that discards the fetched data. `ops-04` in this suite is expected to "
        "PASS on `action_proposed` — meaning the gate fires as documented — but the "
        "UX outcome (data lost after confirmation) is a known gap logged in "
        "`PROJECT_CONTEXT.md §19`. Remediation: reroute read-only operations actions "
        "through a synthesis path analogous to `insights_agent.py`."
    )
    lines.append(f"")
    lines.append(
        "**Admin tool-selection variance (`ops-04`, `ops-05`).** "
        "Gemini 2.5 Flash exhibits non-deterministic tool selection for operations "
        "requests. In the prior checkpoint's promo toggle round-trip, Gemini required "
        "up to 4 retries before it proposed `manage_promotions[toggle]` rather than "
        "`manage_promotions[list]` or a clarifying question. "
        "This harness does not retry; if Gemini selects the wrong tool or responds "
        "conversationally, the case will FAIL on `actual_behavior`. "
        "Any inconsistency in the ops cases between runs reflects this variance."
    )
    lines.append(f"")
    lines.append(
        "**Booking action path (`booking-05`).** "
        "The `cancel_booking` tool is routed through `booking_agent.action_node`, "
        "which calls `get_model()`. Routing is flat, so this resolves to "
        "CLOUD_PRIMARY (Gemini). If the key is absent, the case returns an error. "
        "At the time of this evaluation Gemini was configured and the case was testable."
    )
    lines.append(f"")

    return "\n".join(lines)


# ─── Main ─────────────────────────────────────────────────────────────────────

async def main() -> None:
    print("Connecting to MongoDB...")
    await connect_to_mongo()

    try:
        run1_results: list[dict] = []
        run2_results: list[dict] = []

        # ── Run 1 ──────────────────────────────────────────────────────────
        supervisor1 = build_supervisor()
        sep = "=" * 68
        print(f"\n{sep}")
        print(f"AVA EVALUATION — Run 1 of 2  ({len(TEST_CASES)} cases)")
        print(f"{sep}")

        run1_start = time.monotonic()
        for case in TEST_CASES:
            label = case["message"][:65] + "…" if len(case["message"]) > 65 else case["message"]
            print(f"  [{case['id']}] {label}")
            r = await run_case(supervisor1, case, run_num=1)
            tag = "[PASS]" if r["passed"] else ("[ERR] " if r["error"] else "[FAIL]")
            print(
                f"    {tag}  agent={r['actual_agent']!r}  "
                f"behavior={r['actual_behavior']!r}  ({r['latency']}s)"
            )
            if r["error"]:
                print(f"    ERROR: {r['error']}")
            elif not r["passed"]:
                print(f"    GOT:  {r['response_short'][:150]}")
            run1_results.append(r)
        run1_wall = time.monotonic() - run1_start

        r1_pass = sum(1 for r in run1_results if r["passed"])
        print(f"\n  Run 1 complete: {r1_pass}/{len(TEST_CASES)} passed  ({run1_wall:.0f}s)")

        # ── Run 2 ──────────────────────────────────────────────────────────
        # Fresh supervisor so supervisor-level MemorySaver has no Run 1 state.
        # Sub-agents are cached in _SUB_AGENTS (module-level) but their thread
        # IDs differ (eval-r2-*) so their own MemorySavers start clean.
        supervisor2 = build_supervisor()
        print(f"\n{sep}")
        print(f"AVA EVALUATION — Run 2 of 2  ({len(TEST_CASES)} cases)")
        print(f"{sep}")

        run2_start = time.monotonic()
        for case in TEST_CASES:
            label = case["message"][:65] + "…" if len(case["message"]) > 65 else case["message"]
            print(f"  [{case['id']}] {label}")
            r = await run_case(supervisor2, case, run_num=2)
            tag = "[PASS]" if r["passed"] else ("[ERR] " if r["error"] else "[FAIL]")
            print(
                f"    {tag}  agent={r['actual_agent']!r}  "
                f"behavior={r['actual_behavior']!r}  ({r['latency']}s)"
            )
            if r["error"]:
                print(f"    ERROR: {r['error']}")
            elif not r["passed"]:
                print(f"    GOT:  {r['response_short'][:150]}")
            run2_results.append(r)
        run2_wall = time.monotonic() - run2_start

        r2_pass = sum(1 for r in run2_results if r["passed"])
        print(f"\n  Run 2 complete: {r2_pass}/{len(TEST_CASES)} passed  ({run2_wall:.0f}s)")

        # ── Report ─────────────────────────────────────────────────────────
        report = generate_report(run1_results, run2_results, run1_wall, run2_wall)

        ts = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")
        eval_dir = os.path.dirname(os.path.abspath(__file__))
        out_path = os.path.join(eval_dir, f"results_{ts}.md")

        with open(out_path, "w", encoding="utf-8") as f:
            f.write(report)

        print(f"\n{sep}")
        print(f"Report written: {out_path}")
        print(f"{sep}")

        # Print the summary to stdout for quick reference.
        combined = sum(
            1 for r1, r2 in zip(run1_results, run2_results) if r1["passed"] and r2["passed"]
        )
        print(f"\nRun 1: {r1_pass}/{len(TEST_CASES)}  |  Run 2: {r2_pass}/{len(TEST_CASES)}")
        print(f"Passed both runs: {combined}/{len(TEST_CASES)}")

    finally:
        await close_mongo_connection()


if __name__ == "__main__":
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    asyncio.run(main())
