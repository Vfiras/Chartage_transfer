# Evaluation Methodology — AVA Assistant

*Draft for review. Describes how the AVA assistant is tested, the real harnesses in the repo,
and the testing discipline adopted over the project.*

---

## 1. What we evaluate

AVA is a LangGraph supervisor that routes a user turn through
`classify_intent → role_gate → dispatch → safety_check → session_write`, dispatching to one of
six sub-agents (booking, support, loyalty, feedback, operations, insights). Evaluation targets
three distinct properties:

1. **Routing correctness** — does a turn reach the right agent (and do client→admin requests get
   refused)?
2. **Behaviour correctness** — does it do the right *kind* of thing (read/lookup vs propose a
   gated action vs confirm vs honestly admit missing info)?
3. **Output safety** — no leakage of tool names/internals/JSON; no fabricated success; no
   ungrounded "facts".

## 2. The harnesses (all in `backend/app/ai/`)

### 2a. Scripted scenario suite — `evaluation/run_eval.py` (28 cases)
- 28 cases spanning all six agents (`evaluation/test_cases.py`), each with `expected_agent` and
  `expected_behavior` (`lookup | action_proposed | action_confirmed | rag_answer |
  rag_low_confidence | refused`), some with a `follow_up` turn (e.g. "yes" to confirm a gate).
- Runs the **full supervisor pipeline twice** (isolated thread ids per run), then emits a
  markdown report (`results_<timestamp>.md`) with: per-run pass tables, per-agent pass rates,
  latency, inferred model tier, and a **non-determinism check** (flags any case whose
  agent/behaviour differs between the two runs).
- Coverage: booking ×5 (incl. the persona-leak regression guard), support ×5 (3 KB-backed
  answers + 2 deliberate "should admit uncertainty" cases), loyalty ×4, feedback ×3
  (incl. a full propose→confirm round-trip), role-block ×3 (client→admin refusals),
  operations ×5, insights ×3.

### 2b. Persona-leak guard — `agents/test_persona_leak.py`
- **Section 1:** booking lookup BEFORE (replays the old no-persona path to *reproduce* the leak)
  vs AFTER (the patched graph) — proves the fix and guards against regression.
- **Section 2:** a "how do I…" sweep across all six agents; asserts no forbidden markers
  (tool names, `_id`, `user_id`, ```` ``` ````).
- **Section 3:** a deterministic (no-LLM) check of the confirmation-gate copy
  (`format_tool_summary` / `humanize_result`) for every tool — these hardcoded strings can't be
  reached by the persona prompt, so they're checked directly.

### 2c. Routing / safety CLI — `test_supervisor_cli.py`
- Client multi-domain session; client→admin refusal (+ `audit_log` entry); admin classification;
  a keyword-classification + safety-gap regression; booking-history phrase coverage; and a
  **10-run routing-stability** pass that reports per-phrase misclassification counts.

### 2d. Component tests
`test_model_router.py` (tier policy), `test_tool_registry.py` / `test_tools_client.py`
(tool binding + per-user scoping), `test_rag.py` (retrieval).

## 3. Model-tier-aware testing & quota

- Routing/classification/RAG-retrieval run on **LOCAL** (`llama3.1:8b`); synthesis and all admin
  work run on **CLOUD** (Gemini 2.5 Flash). The cloud free tier is **20 requests/day** (confirmed
  by a live `429 RESOURCE_EXHAUSTED` naming `GenerateRequestsPerDayPerProjectPerModel-FreeTier`,
  `quotaValue: 20`).
- Consequence: after synthesis moved to the cloud, most *client* cases also consume quota, so a
  full real-config eval (~40+ cloud calls) exceeds the daily cap. For quota-free baselines we
  patch `CLOUD_PRIMARY → LOCAL_MODEL`, which exercises the full routing/gate/leak machinery on
  LOCAL. This validates routing and behaviour shape; it does **not** reflect production synthesis
  quality for admin/synthesis cases (they run on the smaller local model), which is stated
  explicitly whenever a LOCAL baseline is reported.

## 4. Testing discipline (what we learned to insist on)

- **Real before/after text, never a boolean.** Multiple bugs (vehicle-name fabrication, the
  50%/refund RAG figures, the loyalty "49 trips" math) passed their automated keyword checks
  while the actual output was still wrong, because the check matched the *old symptom's* exact
  wording. The rule became: read the literal response; the boolean is a hint, not the verdict.
- **For RAG, capture retrieval + scores, not just the answer.** That is what proved the policy
  hallucination was a *stale index* (false-confidence retrieval) rather than a prompt failure —
  and therefore what told us a prompt change would be useless and a rebuild was the fix.
- **Diagnose before fixing.** A short trace (tool JSON → literal synthesis prompt → response,
  on both LOCAL and CLOUD) decided whether moving synthesis to the cloud would fix a bug "for
  free" or whether it needed a separate (tool-level) fix.
- **UI evidence is screenshots, not assertions.** Flutter renders to a single canvas and is not
  reliably automatable via `uiautomator`/blind taps, so UI claims are backed by emulator
  screenshots (and, where login+nav automation is unreliable, login-enabled dev entrypoints that
  render the real widget/screen).
- **Sanity-check the riskiest recent changes first.** The overnight maps/Kotlin sanity pass
  caught a latent backend crash-on-restart (an unexpected env var failing strict Settings
  validation) that was invisible to the already-running process.

## 5. How to run

```
cd backend
python -m app.ai.evaluation.run_eval          # 28-case suite ×2 → results_<ts>.md
python -m app.ai.agents.test_persona_leak     # leak guards
python app/ai/test_supervisor_cli.py          # routing/safety/stability
```
For a quota-free baseline, run the same with `CLOUD_PRIMARY` patched to `LOCAL_MODEL`
(see `scratchpad/run_eval_local.py`), noting that admin/synthesis cases then run on LOCAL.

## 6. Latest baseline
Most recent baseline: `backend/app/ai/evaluation/results_2026-06-30_10-29-26.md` — a non-Gemini
(LOCAL) run, **24/28 as-run → 25/28** after correcting one stale expectation (`ops-04`, whose
read-only fleet-list behaviour was just changed from gated `action_proposed` to data-showing
`lookup`). The remaining 3 failures are LOCAL-model artifacts (admin classification + RAG
confidence calibration on `llama3.1:8b`) that are expected to pass on the production Gemini tier,
not code regressions. Note: the report's "Tier" column is a policy label (`infer_tier`); admin
cases show "CLOUD" but actually ran on LOCAL in this baseline. See OVERNIGHT_LOG Task 3 for the
per-case diagnosis.
