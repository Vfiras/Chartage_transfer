# Bug & Fix Log — AVA Assistant (with before/after evidence)

*Draft for review. Each entry is a real bug found during this project, its root cause, the fix,
and the actual before/after behaviour captured during verification (not paraphrased summaries).*

---

## 1. Persona leak — assistant answered like a developer

- **Symptom:** "How do I track my ride?" produced developer-tutorial text leaking tool names and
  internals.
- **Before:** *"To track your ride… 2. Get trip history: …calling the `/get_trip_history`
  endpoint… ``` GET /get_trip_history?user_id=test-client-ava-001 ```"* (leaked
  `get_trip_history`, `user_id`, code fences).
- **Root cause:** user-facing model calls ran with no persona system prompt.
- **Fix:** prepend `AVA_PERSONA_PROMPT` (strict no-internals rules) to every user-facing call;
  `extract_text` strips structured blocks.
- **After:** *"…you have no upcoming trips at the moment. Your past trips include: a completed
  one-way trip from Tunis Airport to Hammamet on June 26…"* — leak markers: none.

## 2. Trip-tracking deflection (BUG1a)

- **Before:** "How do I track my current ride?" → *"…Can you please confirm your pickup location
  and destination city?"* (deflected instead of using the tool).
- **Root cause:** missing "you are the customer's direct interface" rule; classifier looped on
  confirm-location.
- **Fix:** persona rule 6 (use your tools, don't tell the user to navigate) + booking lookup
  reports real trip data.
- **After:** *"Your trip from Tunis Airport to Hammamet on June 26th at 10:00 has been
  completed…"*

## 3. Cancellation "how-to" gave navigation steps, not policy (BUG1b)

- **Before:** "How do I cancel my booking?" → app-navigation steps + "check your email".
- **Root cause:** support agent had no synthesis rules; model free-styled.
- **Fix:** `_SUPPORT_ADDENDUM` (answer from KB only; if it's an action, offer to do it).
- **After:** *"…free of charge up to 24 hours before your scheduled departure… If you'd like me
  to handle that for you right now, just say the word."*

## 4. Disambiguation crash (BUG2)

- **Before:** "please cancel my upcoming booking" (no booking id) → *"I apologize — something
  went wrong processing your request."*
- **Root cause:** two issues — (a) the action path needed a booking id it didn't have;
  (b) the 0-candidates message contained the word "cancelled", which is in `_SUCCESS_KEYWORDS`,
  so `safety_check_node` flagged it as a false success claim.
- **Fix:** new `disambiguate_node` / `resolve_selection_node` (list candidates, resolve by
  ordinal/city before the gate); 0-result copy reworded to "eligible for cancellation" to avoid
  the safety-keyword false positive.
- **After:** *"I don't see any upcoming bookings on your account that are eligible for
  cancellation right now…"* (and, with upcoming bookings, a numbered selection card).

## 5. Vehicle-name fabrication (BUG3) — the trace that corrected the diagnosis

- **Before (LOCAL synthesis):** "What car do you recommend for 2 passengers and 3 large bags?" →
  *"I would recommend a **Standard Comfort sedan**…"* — a name that appears nowhere in the data.
- **Trace finding:** the `recommend_vehicle` tool returns clean DB values
  (`name:"Standard", model:"Comfort sedan"`, plus VIP/"Executive sedan", Van/"Premium group
  van"). The local model **fused** `name`+`model` into "Standard Comfort sedan" despite an
  explicit "use exact values only" instruction. The tool was not at fault; the synthesis step
  was. (Note: "Executive sedan" — once thought invented — is a *real* DB model name for VIP.)
- **Fix:** route client synthesis to CLOUD (`client_synthesis` tier). Gemini obeys the
  exact-values rule; a deterministic template is the cloud-outage fallback.
- **After (CLOUD synthesis):** *"…I would recommend the **Van** category, specifically the
  **Premium group van** model… 7 seats and 5 pieces of luggage"* — exact DB values, and it even
  reasons that 3 large bags need the Van (the Standard only fits 2).

## 6. RAG hallucination of policy figures (BUG4) — root cause was the data layer, not the model

- **Before:** "How do I cancel my booking?" → *"…incur a fee of **50% of the total booking
  value**. No-shows are charged the full amount. Refunds… within **5–10 business days**."* None
  of which is in the published policy.
- **Diagnosis (decisive):** capturing the retrieved chunks + relevance scores showed the model
  was faithfully grounding in retrieved text — but the **vector store was stale**, built from an
  old "placeholder" KB generation (numbered §3.2/3.3, 50%/100% tiers, a loyalty-points section)
  that the current files had since removed. So this was *false-confidence retrieval*, not a
  rule-5 failure. A prompt change would have done nothing.
- **Fix:** rebuild the index from the corrected files; add a 0.25 relevance floor; add a
  startup staleness guard (per-file SHA-256 manifest).
- **After (rebuilt index):** "Cancellation fee if <24h?" → *"…may be subject to charges. However,
  the exact cancellation fee percentage is **not specified** in our published policy."*; refund
  timeframe → *"I don't have the specific details… please contact our team."* Stale figures gone.

## 7. Admin-gate false refusal (BUG5)

- **Before:** "How long does a transfer to Tunis airport take?" → *"I'm sorry, but that request
  requires administrative access."* (a client question wrongly refused).
- **Root cause:** `_keyword_classify` returned a hardcoded `"support"` on no-match; the model
  said `"operations"`; an over-eager guard forced the model's domain → role_gate refused.
- **Fix:** `_keyword_classify` returns `Optional[str]` (None on no-match); Guard 2b only
  overrides when there's a positive keyword hit, so no-keyword messages trust the (support)
  classification.
- **After:** answers the travel-time question normally; no refusal.

## 8. Loyalty tier math (caught by reading the text, not a boolean)

- **Tool data:** `points=10, completed_trips=1, next_tier_threshold=50` (points). Correct answer:
  **40 more points = 4 more trips**.
- **Before (LOCAL):** *"…complete 50 trips."* **Before (CLOUD, first attempt):** *"…you are 49
  trips away from reaching Silver."* — both wrong. The automated check only grepped "50 trips",
  so the cloud "49 trips" silently passed while still wrong; reading the actual sentence caught it.
- **Root cause:** an arithmetic/units problem, not instruction-following — the tool handed over a
  raw threshold with no unit and no precomputed gap, so the model guessed.
- **Fix:** `get_user_promos` now returns precomputed, labelled `points_to_next_tier` (40),
  `trips_to_next_tier` (4), `points_per_trip` (10); plus a deterministic loyalty template for the
  cloud-outage path. Top-tier handled (gaps = 0, no negatives).
- **After (CLOUD):** *"…You are 40 points away from reaching Silver tier, which typically requires
  4 more completed trips."* Top-tier: *"…that's our highest tier, so there's no further
  requirement."*

## 9. Backend crash-on-restart from the Maps key (caught by the overnight sanity check)

- **Symptom:** after adding `MAPS_API_KEY` to `backend/.env`, the backend failed any fresh start:
  `ValidationError: maps_api_key Extra inputs are not permitted` (Settings uses `extra=forbid`).
  The running process was unaffected (it had loaded `.env` before the change), so it was latent.
- **Fix:** declare `maps_api_key: str = ""` in `app/core/config.py` (backend accepts it; doesn't
  use it). Verified config now imports cleanly.

## 10. Read-only admin gating dropped the data

- **Before:** "show me the current fleet list" → *"I'd like to pull up the current fleet list.
  Reply **yes** to confirm…"* → after confirming, *"Done — I've pulled up the current fleet."*
  with the actual list discarded by `humanize_result`.
- **Root cause:** `operations_agent` routed *all* tools — including read-only list/get — through
  the confirmation gate.
- **Fix:** read-only actions (`manage_fleet[list]`, `manage_pricing_rules[get]`,
  `manage_suppliers[list]`, `manage_promotions[list]`) now execute immediately and synthesise the
  data (the `insights_agent` pattern); writes stay gated.
- **After:** *"Standard — Comfort sedan, 4 seats, 2 luggage, base price 18, available; VIP —
  Executive sedan, 3 seats, 28…; Luxury…; Van — 7 seats, 5 luggage, 50…"* — no gate, data shown.
  Writes ("Add a new vehicle…") still propose "Reply **yes** to confirm".

---

### Cross-cutting lesson
Several of these (BUG3, BUG4, the loyalty math) shared a pattern: **the automated boolean check
agreed the bug was fixed while the actual output was still wrong.** Reading the literal
before/after text — and, for RAG, capturing the retrieved chunks + scores — was what
distinguished a real fix from a symptom that merely changed shape. That discipline (real
evidence over green checkmarks) is reflected in the evaluation methodology.
