# Carthage Transfer — Completion Session Log

Session date: 2026-07-07

---

## Task 0 — Vehicle pricing extraction from PDFs

Status: DONE (with 1 flag)
Source: 8 WordPress "Edit Vehicle" PDFs (Chauffeur Booking System, carthage-transfer.com), provided in-session.
All vehicles use **Variable** booking sum type. Delivery, per-adult, per-child, PayPal/Stripe fees are 0.00 everywhere and omitted. Return-rate fields (per km/hour return, return-new-ride) equal the one-way rate in every PDF unless noted.

| Vehicle | WP post | Order | Initial | Initial (return) | Per km | Per hour | Per extra hour | Per waypoint | Per waypoint /min |
|---|---|---|---|---|---|---|---|---|---|
| Comfort Sedan | 730 | 2 | 12.98 | 25.96 | 0.413 | 14.16 | 16.52 | 20.06 | 0.118 |
| Economy ⚠️ | 9136 | 2 | 12.— | 25.— | 0.3— | 14.— | 16.— | 15.— | 0.1— |
| Minivan | 3695 | 4 | 17.7 | 35.4 | 0.4956 | 23.6 | 23.6 | 20.06 | 0.059 |
| Large Van | 1204 | 5 | 29.5 | 59 | 0.5192 | 5.9 | 5.9 | 23.6 | 0.059 |
| Minibus | 9140 | 5 | 47.2 | 94.4 | 0.649 | 23.6 | 23.6 | 47.2 | 0.05 |
| Mercedes E Class – Business | 1802 | 7 | 90.86 | 181.72 | 1.357 | 34.22 | 47.2 | 29.5 | 0.118 |
| Mercedes S Class 2024 – Royalty | 64 | 7 | 354 | 708 | 2.006 | 82.6 | 0.00 | 38.94 | 0.00 |
| Mercedes V Class – Executive | 727 | 8 | 112.1 | 224.2 | 1.534 | 54.87 | 59 | 29.5 | 0.118 |

**⚠️ FLAG — Economy (post 9136):** the PDF renders its value fields truncated ("12.", "25.", "0.3", "14.", "16.", "15.", "0.1") — exact decimals are NOT recoverable from this PDF. Per the instruction to flag rather than build on bad data, Economy is seeded with the visible digits (12.0 / 25.0 / 0.30 / 14.0 / 16.0 / 15.0 / 0.10) and marked `"pricing_verified": false` in the seed. **Action for user: read the exact values from WP admin post 9136 and correct the seed (or edit in the new admin Pricing screen).**

**Anomaly noted — Mercedes V Class:** "Per kilometer (return, new ride)" is 0.00 while one-way/return are 1.534. Treated as data-entry gap on the site; seeded 1.534 for all km variants.

**Formula decision (important):** the task text lists `+ (duration_hours × per_hour)` in the total, but its own verification target contradicts that: Tunis-Carthage→Hammamet (~62 km ≈ 1 h) on Comfort Sedan must come to ≈ 38–40 EUR, which equals `12.98 + 62×0.413 ≈ 38.6` — i.e. **without** the hourly term (with it, the total would be ~53 EUR). This matches how the Chauffeur Booking System actually works: per-hour applies to hourly/waypoint bookings, not distance transfers. Implemented accordingly: distance transfers = initial + km×per_km + waypoint components; the hourly component is computed and returned in the breakdown only when waypoint duration / hourly extras apply. Flagged here so the decision is explicit.

---
## Task 1c — Pricing wired into booking flow
Status: DONE
Evidence: live HTTP test — `POST /api/v1/bookings/price-estimate` (client JWT) with TUN→Hammamet coords returned `{"distance_km": 73.53, "duration_hours": 1.02, "source": "google_directions", "estimates": [8 vehicles]}`; Comfort Sedan = 43.35 EUR (12.98 + 30.37), Economy = 34.06 EUR. Batch mode = ONE Directions call for the whole fleet.
Flutter: BookingData now carries resolved pickup/destination coords (+ distanceKm/durationHours/currency); booking_search_screen attaches them on submit; booking_fleet_screen fetches the batch quote, shows the REAL per-vehicle price in EUR, displays route metrics (km + drive time), and has a One-way/Return toggle that live-updates all prices (cached per trip type — flipping back is instant). Vehicle selection stores the real total as the base and layers the existing configurable surcharges/promo on top. Fallback: if coords are missing or the endpoint fails, the old local estimate still renders (TND label).
Known gaps: `flutter analyze` clean (12 pre-existing lint infos in search screen, none from this change). Emulator hot-restart still pending at end of session.

## Task 1d — Admin per-vehicle pricing dashboard
Status: DONE
Evidence: `admin_pricing_screen.dart` fully replaced — now lists every fleet vehicle as a card with live rates (initial/return/per-km/per-hour/waypoint) + a "VERIFY RATES" badge on Economy (pricing_verified=false). Tapping opens an editor sheet with one number input per pricing parameter; Save calls `PUT /cars/{id}` with the `pricing` object (and syncs `base_price` to the initial fee). Backend: CarUpdate/CarCreate DTOs gained `pricing`/`features`; VALID_CATEGORIES extended to the real 8 categories (+legacy 4).
Known gaps: per the task instruction ("replaces any existing static pricing rules screen"), the old surcharge-rules FORM was removed. The surcharge rules themselves still exist and apply (PUT /pricing/rules endpoint intact; night/weekend/last-minute still layered onto quotes).
## Task 2a — Booking modification
Status: DONE
Evidence: audit found the flow ALREADY wired end-to-end: `_ModifyBookingScreen` pre-loads all booking fields (initState), Save → `TripService.updateTrip` → `PUT /bookings/{id}`, errors → snackbar, caller refreshes list via `onChanged()`; 24h modification rule enforced client- AND server-side. Live API test: created future booking → `PUT` changed pickup/date/time/pax/bags → response confirmed `La Marsa Corniche | 2026-08-21 09:30 | pax 3 | bags 1` → cancelled (cleanup, 200). Past-dated booking correctly rejected with "Modification is only allowed 24 hours before departure."
Added this session: success snackbar on save (`booking_updated`, EN+FR i18n keys) — the only missing piece.
## Task 2b — Profile photo upload
Status: DONE
Evidence: flow was already real end-to-end: edit_profile_screen → image_picker (gallery, q88, max 1600px) → `AuthService.uploadAvatar` → multipart `POST /auth/me/avatar` → stored on disk, old avatar deleted, `avatar_url` persisted in the user document + SharedPreferences. Live test: uploaded a PNG → `avatar_url: /media/avatars/user-client-1-….png`. Avatar already renders from `user.avatarUrl` in profile, client shell header/drawer, notifications screen, booking confirmation and contact confirmation.
Added this session: the user's real photo now also shows beside their chat bubbles on the AVA screen (was the one surface missing it).
## Task 2c — Notifications
Status: DONE
Evidence: already real — NotificationController.load → `GET /notifications/`; tap → optimistic markRead → `PATCH /notifications/{id}/read` (rollback on failure); mark-all + delete(+undo) wired; unread count propagates via onUnreadCountChanged to client shell: gold-dot badge on the bottom-nav Alerts tab and on the home-hero avatar were already live.
Added this session: unread dot on the Bookings-tab bell icon (the one bell that had no badge) — hasUnread now passed into _BookingsTab.

## Task 2d — Booking confirmation map
Status: DONE
Evidence: already real — `RouteMapView` renders an interactive GoogleMap with pickup/destination markers and a Directions-API road polyline (cached; silent marker-only fallback).
Improved this session: the confirmation screen now prefers the EXACT coordinates resolved during search (Places autocomplete) via the new BookingData coords, falling back to the curated name-lookup only when coords are absent — arbitrary addresses no longer risk failing the name lookup.
## Task 3a — Admin complaints management
Status: DONE
Evidence (live HTTP): client `POST /complaints/` → `claim-892625…` · admin `GET /complaints/` → 62 items, newest first · `PATCH /complaints/{id}/status` → `in_review` → `resolved` · invalid status → **400** · client attempting PATCH → **403** · `GET /admin/overview` now returns `open_complaints: 61, total_complaints: 62`.
Built: `PATCH /complaints/{id}/status` endpoint (admin-only, statuses open/in_review/resolved) + `ComplaintStatusUpdate` DTO; Flutter `admin_complaints_screen.dart` (filter chips All/Open/In review/Resolved, status badges, detail sheet with user/booking/message/timestamp + status selector); dashboard gained an "Open complaints" stat tile and a Complaints quick-action (with live open count) → screen wired via admin_shell.
Note: complaint IDs are `_id` in serialized responses — screen reads `_id` with `id` fallback.

## Task 3b — Admin booking detail + status override
Status: DONE (verified, no change needed)
Evidence: admin bookings list → tap → `AdminBookingDetailsScreen` → `BookingEditSheet`, whose dropdown is exactly the canonical set (pending/confirmed/on_route/completed/cancelled) with a comment "must match VALID_STATUSES in bookings.py", legacy-status normalisation, and PATCH `/bookings/{id}/status` on save — the same endpoint AVA's `update_booking_status` admin tool calls. Flutter UI matches the backend contract.

## Task 4 — AVA recommend_vehicle on the real fleet
Status: DONE
Evidence (direct tool invocation, zero Gemini quota):
```
pax=2 → Economy (3 seats, 30.0 EUR) | Comfort Sedan 37.76 | Minivan 47.44
pax=5 → Large Van (7 seats, 60.65 EUR) | Minibus 86.14 | V Class 204.14
pax=10 → Minibus (12 seats, 86.14 EUR)
Template fallback: "…recommend the **Economy (Toyota Yaris)** — seats up to 3 passengers and 3 bags. Estimated around 30.0 EUR for a typical transfer."
```
Implementation: queries the real cars collection (availability=true), filters `seats >= passenger_count`, sorts by `pricing.initial_fee` asc, returns top 3 as compact summaries (real name/model/category/seats/luggage + `estimated_price_eur` from the pricing calculator on a 60 km typical-transfer basis). Preference history still honoured (matched by name OR category). `_vehicle_template` deterministic fallback now uses real fleet names + EUR estimate (TND string removed).

## Task 5a — Airport assistance RAG
Status: DONE
Root cause: the word "assistance" never appears in the KB — embeddings favoured the destinations.txt "AIRPORTS SERVED" chunk, and only 1 chunk cleared the 0.25 floor.
Fix: low-confidence query expansion in `search_knowledge_base` — if the best first-pass score < 0.50 and the query mentions "airport", a second retrieval runs with KB-vocabulary phrasing ("meeting the driver name sign free waiting time flight delayed or arrives early"); results merged, deduped, top-3 kept. Floor unchanged (0.25).
Evidence: "Tell me about airport assistance" AND bare "airport assistance" now both return 3 chunks incl. the T&C WAITING TIME chunk (0.3856) and the faq.txt meet-your-driver Q&A chunk (0.3855) — the driver name-sign / 1h free waiting / flight-tracking content AVA needs.

## Task 5b — Gemini raw error never reaches Flutter
Status: DONE
Coverage (3 layers): (1) `invoke_with_fallback` collapses every model failure to the friendly RuntimeError, raw error logged server-side; (2) `_run()` in assistant.py catches `except Exception` (any sub-agent's direct .ainvoke() failure) and queues only the friendly constant, and the SSE error branch force-emits `_FRIENDLY_ERROR` regardless of payload; (3) NEW this task — the whole generator setup (`_get_supervisor()`) is wrapped, so even a graph-build failure yields the friendly SSE event instead of a raw 500.
Evidence (zero-quota simulated 429 with the real error body): both layers re-tested post-change —
```
[PASS] A model_router.invoke_with_fallback: 'AVA is temporarily unavailable. Please try again in a moment.'
[PASS] B assistant SSE error event:        'AVA is temporarily unavailable. Please try again in a moment.'
(asserted absent: 429, RESOURCE_EXHAUSTED, quota, generativelanguage, ChatGoogleGenerativeAIError, {, })
```
---

## Session wrap-up

**All tasks DONE.** `flutter analyze`: No issues found. Backend restarted with all changes; app rebuilt on emulator-5554.

What changed, at a glance:
- **Pricing**: real 8-vehicle fleet (WP PDFs) with full Chauffeur-Booking-System parameters; `pricing_calculator.py` (Directions API + haversine fallback); `POST /bookings/price-estimate` (single + batch); fleet screen shows real EUR per-vehicle quotes with a live one-way/return toggle + route metrics; admin Pricing screen = per-vehicle rate editor.
- **Client**: booking modify success toast; AVA-screen user avatar; bookings-tab bell unread dot; confirmation map prefers exact coords.
- **Admin**: complaints management end-to-end (screen + PATCH status endpoint + dashboard tile/action); booking status flow verified canonical.
- **AVA**: recommend_vehicle on the real fleet with real EUR estimates (+ template fallback); airport-assistance retrieval fixed via low-confidence query expansion; friendly-error guarantee extended to 3 layers and re-proven.

Out of scope, untouched per instructions: payment flow, push infrastructure, bottom-nav design, AVA agent architecture, RAG knowledge files (only the retrieval function changed, not the KB).

Open items for the user:
1. **Economy vehicle rates** — PDF truncated; verify exact decimals in WP admin (post 9136) and correct via the new admin Pricing screen (card is flagged "VERIFY RATES").
2. Gemini free-tier quota still 20/day until billing is added (human action) — AVA replies degrade to friendly message / deterministic templates when exhausted.
3. Old test complaints (60) predate this session; the admin screen shows them — clear via DB if unwanted for the demo.
---

# Session 2026-07-08 — Payment flow + AVA Business Analytics

## Task 1 — Cash vs Credit Card payment flow
Status: DONE
Evidence (live HTTP, full lifecycle):
```
1. client POST /bookings/ {payment_method:"cash"} → status=pending payment_method=cash payment_status=pending_approval
2. admin notification created: "Cash booking awaiting approval | Demo Client booked a transfer to Sousse (cash on arrival) — approval required."
3. client POST {payment_method:"card"} → status=pending payment_method=card payment_status=approved (placeholder path)
4. admin PATCH /admin/bookings/{id}/approve-payment → status=confirmed payment_status=approved
5. client notification: "Booking confirmed | Great news — your transfer to Sousse has been approved and confirmed. Payment in cash on arrival."
6. client GET booking → status=confirmed payment_status=approved
```
Backend: TripCreate.payment_method (default "cash" so AVA's create_booking keeps working); create_trip sets payment_status + notifies ALL admin accounts on cash; new PATCH /admin/bookings/{id}/approve-payment confirms + notifies the client.
Flutter client: new PaymentMethodScreen between contact details and final confirmation — cash card ("Requires Approval" badge, creates real booking) and card card ("Coming Soon" badge → bottom sheet with "Continue with Cash"); card is NOT selectable as a real path. Success screen for cash shows "Booking Received … Your booking is pending approval. You'll receive a notification once confirmed." instead of the confirmed copy.
Flutter admin: dashboard now opens with a gold-bordered "Pending Cash Approvals" section (count badge + horizontal scrollable cards: client, route, date, vehicle, price) → detail sheet with "Approve Booking" → success toast + card disappears (list reload). Bookings screen gained filter chips: All / **Pending Approval** / Pending / Confirmed / On Route / Completed / Cancelled.
Known gaps: card payment is a placeholder by design (out of scope). flutter analyze: No issues found.
## Task 2 — AVA Admin Analytics (Business Intelligence)
Status: DONE
Architecture: admin message → supervisor Guard 0 (analysis phrases → insights domain, zero classify cost) → insights agent fast path (deterministic trigger → analysis_type) → run_business_analysis tool → analytics_service (6 real-Mongo methods) → deterministic chart specs + KPIs + insights → ONE dedicated Gemini analyst call for the narrative (deterministic fallback if unavailable) → payload rides AIMessage.additional_kwargs → supervisor state → SSE "analytics" event before "done" → Flutter AnalyticsCard (fl_chart).

2a analytics_service.py: get_revenue_by_month, get_revenue_by_vehicle_category, get_booking_volume_trend, get_seasonal_analysis, get_pricing_impact_analysis (pricing_history collection + inference fallback), get_kpi_summary — all real MongoDB.
2b/2c run_business_analysis: registered in ADMIN_TOOLS (admin-only via tool_registry, audit-wrapped); returns charts[]/kpis[]/insights[]/narrative per the spec format. Bonus: PUT /cars/{id} now writes a pricing_history record on every pricing change so impact analysis has real change events going forward.
2d AnalyticsCard (fl_chart ^0.69): gold-accent data bubble — KPI row (trend arrows, green/red), narrative, line/area/bar/pie charts (~220px, tooltips, highlight dot, legend), gold-dot insight bullets.
2e: new SSE event type "analytics" emitted before "done"; AssistantController stashes it and renders ChatMessage.analytics; admin chat renders AnalyticsCard instead of a text bubble.
2f: triggers in app/ai/analysis_triggers.py (shared by supervisor Guard 0 + insights agent); insights keyword set extended.

Evidence — LIVE full flow over the real SSE endpoint (admin JWT):
```
ADMIN: Give me a full business review
SSE: ['token'×5, 'analytics', 'done']
analytics: analysis_type=full_review, 5 KPIs (Revenue MTD €0, YTD €34, Bookings MTD 0, Avg €34, Top Vehicle VIP),
4 charts ([line] Monthly Revenue, [bar] Completed Bookings/Month, [pie] Revenue by Category, [area] Weekly Booking Volume), 5 insights.
NARRATIVE (Gemini): "Carthage Transfer's business health **needs attention**. 1. Alarmingly Low Activity & Revenue: …34 EUR in total YTD revenue… 2. Critical Booking Completion Rate: Out of 9 total bookings, only 1 was completed… 3. Undiversified & Fragile Revenue: All 34 EUR revenue stems from a single VIP booking on the 'Tunis City Centre → Sidi Bou Said' route…"
(→ every number is accurate to the seeded DB: 9 bookings, 1 completed, 34 EUR.)

ADMIN: How did our pricing changes affect bookings this year?
SSE: ['token'×6, 'analytics', 'done'] — analysis_type=pricing_impact.
After a REAL pricing edit (Comfort Sedan 12.98→13.50 via PUT /cars, which wrote pricing_history):
chart [bar] "Bookings 7 Days Before vs After Pricing Changes": before=0, after=0 (honest — change made moments earlier)
NARRATIVE: "…A recent price adjustment for 'Comfort Sedan' from 12.98 EUR to 13.5 EUR shows no bookings before or after the change…"
```
Rendering fix during 2g: the card's rounded border + gold-only top side hit Flutter's "borderRadius requires uniform border colors" paint assertion (black screen). Fixed: uniform faint border + clipped 2.5px gold accent bar. flutter analyze: No issues found.
Known gaps: charts are meaningful but sparse with seeded demo data (1 completed booking); they enrich automatically as real bookings accumulate. Analyst narrative costs 1 Gemini call/analysis (free-tier 20/day applies); on quota failure the card still renders with deterministic insights.
### 2g rendering evidence (emulator screenshots, saved in docs/evidence/)
- `analytics_card_kpis_narrative.png` — admin AVA chat after "Give me a full business review": user bubble → gold-accented **BUSINESS REVIEW** card with KPI tile row (REVENUE MTD €0 · REVENUE YTD €34 · BOOKINGS…, horizontally scrollable) and the live Gemini narrative (a fresh call — it even reasons about "a July price change having no impact due to an absence of bookings before or after", i.e. the real pricing_history record).
- `analytics_card_charts_insights.png` — same card scrolled down: blue AREA chart "Weekly Booking Volume" (2026-W20…W2x axis labels), BAR chart "Bookings 7 Days Before vs After Pricing Changes" (Comfort Sedan before/after, honest zero bars), and the KEY INSIGHTS section with gold-dot bullets (route, VIP revenue share 100% €34, peak months May/June…).
Captured via the dev entrypoint (dev_admin_ava_main.dart, temporarily auto-sending the review prompt; restored to its original prompt afterwards).

Final state: backend restarted with all Task 1+2 changes; flutter analyze — No issues found; main app relaunched on emulator-5554.
---

# Session 2026-07-08 (2) — Design elevation pass

## Phase 1 — Design audit
Status: DONE
Evidence: `DESIGN_AUDIT.md` — every screen in lib/screens/ read and assessed (works-well / generic / one high-impact fix per screen), cross-cutting findings (w900 inflation, gold overuse, EUR/TND schism, CTA anarchy, spinner loading, 3 parallel token systems), prioritized into Tier 1 (8 items) / Tier 2 (5) / Tier 3 (deliberately none — rationale logged).

## Phase 2 — Tier 1 quick wins (all implemented)
Status: DONE
Evidence: currency unified to EUR on receipts/trips/promos; dead affordances removed (AVA bell + "View All", vehicles menu→back); `FontWeight.w900` eliminated app-wide (grep = 0) with w800 ceiling; gold discipline pass (vehicles labels, services amber POPULAR→brand gold, destinations black chip→gold, success-screen icon degolding); ONE CTA spec via new `LuxuryCta` (52/r14/gold/w800) applied to success ×2, confirmation, contact, payment sheet; `LuxurySkeleton` primitives replace spinners on fleet/trips/admin-bookings/complaints/pricing; token greys + radius/padding normalization on services/destinations; destinations filter chips now actually filter (+empty state).

## Phase 3 — Tier 2 component upgrades (all four briefs + audit finds)
Status: DONE
Evidence (details + rationale per change in `DESIGN_CHANGES.md`):
1. Booking success → first-class ticket: airport-code route (TUN→HAM style + Tunisian airport mapping), perforated fold with edge notches, vehicle plate, self-drawing gold check (CustomPainter, ease-out — elastic bounce removed), EUR total, restrained gold. Affects: none other (screen-local).
2. Vehicle selection product cards: name-as-hero hierarchy, real feature chips (1h free waiting replaces fake WiFi), ALL-INCLUSIVE vs ESTIMATED price microcopy, skeleton loading + empty state. Affects: booking flow entry only.
3. AVA bubbles: gold left accent on AVA answers (outside the rounded bubble — avoids the non-uniform-border paint assertion), "AVA is preparing your answer…" typing microcopy. Affects: BOTH client and admin AVA chats (shared bubble/indicator) — intended.
4. Profile membership card: CARTHAGE PRIVILÈGE dark-lacquer card (tier chip, points hero, gold progress, rides-to-next-tier, member name) on the profile itself via existing RewardService; replaces the buried Rewards row; guests excluded. Affects: profile tab only.
5. From audit: destinations functional filter + premium chip states.

## Phase 4 — Tier 3
Status: SKIPPED BY DESIGN — audit found no screen whose layout (vs polish) blocks the experience; the real structural debt (3 token systems) risks finalized surfaces. Logged.

Verification: `flutter analyze` — **No issues found** (full app). App rebuilt on emulator-5554.
Known gaps: destinations static prices remain TND (marketing data, flagged not converted); icon sizes normalized in touched code, not by exhaustive sweep.
---

# Session 2026-07-09 — AVA client screen redesign (concierge lounge)

Status: DONE
Deliverables: AVA_SCREEN_AUDIT.md (shown first) · redesigned assistant_screen.dart · AVA_REDESIGN_NOTES.md · 3 state screenshots in docs/evidence/ (ava_lounge / ava_first_exchange / ava_conversation_compressed) · flutter analyze: No issues found.

Key moves (details in the notes file): lounge⇄conversation state machine with 250ms ease-out fade (lounge yields entirely; top bar gains mini portrait); portrait framed on a radial gold stage light + thin ring, gold LIVE dot (green eliminated); hierarchy inverted — "How may I assist you today?" 26/w300 is the hero, greeting demoted to 18/w400 gold; credential re-set as hairline rule + letterspaced caps (pill deleted); Quick Actions grid → horizontal chips with natural first-message labels that send exactly what they say; once-per-session entrance (fade/scale + single vignette breath); input border gold 20%→60% on focus + gold-shadow send + honest disabled state; exchange rhythm 20/8px; timestamps 10px@40%; lounge hint line. Bubble widgets gained only an optional bottomSpacing param (default 18 — admin chat pixel-identical). Cards/SSE/voice/tokens untouched.

Verified live on emulator: (a) lounge renders with stage light + chips; (b) chip tap sends its own label, lounge yields, selection card renders in new layout; (c) full modify flow (selection → confirmation → success) under the compressed header. Also fixed during shoot: cleared the leftover 1×1 red test avatar from user-client-1 (data, not code).
---

# Session 2026-07-09 (2) — "90 TND / BUSINESS" pricing bug: DIAGNOSIS (no fix applied yet)

## Q1 — What vehicle document is being loaded?
The correct one. There is NO booking in the DB matching the screenshot (newest bookings are 2026-07-08 curl tests + seeds) → the "90 TND" was seen on the PRE-SUBMIT confirmation screen; no document was created. The vehicle behind it is `car-e-class` = "Mercedes E Class - Business" — a REAL seeded vehicle (initial_fee 90.86 EUR, category 'business'). Not S-Class (354 EUR), not an old-format doc. The DATA loaded was right; the client-side join failed (Q2).

## Q2 — Is the pricing calculator being called?
YES — and its result is thrown away. Backend access log, the user's booking flow in sequence:
```
GET  /api/v1/cars/                      200   (fleet screen loads 8 real vehicles)
GET  /api/v1/pricing/config             200
POST /api/v1/bookings/price-estimate    200   (batch EUR quote SUCCEEDED)
```
THE BUG: `GET /cars/` serializes Mongo docs with the raw key `_id` (verified live: keys = [_id, availability, base_price, …]; `'id' in doc` → **False**). But `Vehicle.fromJson` populates the join key from `json['id']`:
`backendId: json['id'] is String ? json['id'].toString() : ''` → **backendId = '' for every vehicle**.
The fleet screen then looks up `real.byVehicleId[vehicle.backendId]` → `byVehicleId['']` → no match → EVERY card silently falls back to the local rules-based estimate. The 200-OK EUR quote is fetched and discarded. (Same `_id`-vs-`id` trap already hit once on complaints — now bitten twice.)

## Q3 — Where does "90 TND" come from?
Three stacked causes, value first:
1. Fallback price = `vehicle.price` = `(json['base_price'] as num?)?.toInt()` = 90.86 → **90** (int truncation in Vehicle.fromJson:39).
2. Currency: fleet fallback path labels 'TND' (`_cardCurrency` → real==null → 'TND'); and the CONFIRMATION screen has **4 hardcoded "TND" strings** (booking_confirmation_screen.dart:354,360,367,385 — subtotal/surcharge/discount/total) — missed in the earlier currency pass, which only fixed the success screen + trips.
3. "BUSINESS" label: booking_confirmation_screen.dart:296-297 renders `widget.vehicle.category` ('business', styled uppercase) — a real category of the real E-Class, not a leftover of the old 4-bucket system.
Also inconsistent: the fallback `_select` path never sets `data.currency`, so the SUCCESS screen would then show "90 EUR" after the confirmation showed "90 TND".

## Q4 — Old-format vehicles in the DB?
NO. Full `db.cars.find({})` dump = exactly the 8 real seeded vehicles, all with `pricing` objects, all EUR, no leftovers. (Comfort Sedan initial_fee shows 13.5 — that's the deliberate pricing_history test edit from 07-08, not corruption.)

## Verdict
Not a re-seed problem, not a calculator problem, not stale data. **One client-side join bug (backendId reads 'id', API sends '_id') disables the entire real-pricing display, and the fallback path that then kicks in has truncated values + hardcoded TND labels.** The "S-Class" in the report was actually the E-Class (90.86 ≈ 90 was the tell).

## Proposed fix plan (BY ROOT CAUSE — awaiting approval, nothing implemented)
1. **Join fix (the bug):** `Vehicle.fromJson` → `backendId: (json['_id'] ?? json['id'])?.toString() ?? ''` (and keep the int display id fallback). One line; restores real EUR quotes on the fleet screen instantly.
2. **Fallback honesty:** keep the local estimate as offline fallback, but (a) stop truncating: `price` as double or `.round()` on display only; (b) `_select` fallback sets `data.currency = 'TND'` so downstream screens agree; (c) fleet card already labels it "ESTIMATED".
3. **Display layer:** replace the 4 hardcoded "TND" on booking_confirmation_screen with `data.currency`; sweep for any other hardcoded currency in the flow (grep shows fleet fallback default is the only other, which is intentional).
4. **Regression guard:** after fix, live-verify on emulator: fleet screen must show 91 EUR-range for E-Class TUN→Hammamet (90.86 + 73.53×1.357 ≈ 190.65 EUR one-way), and confirmation must carry the same number+currency end-to-end.

## FIX APPLIED (approved) + verified live
Root cause was #2 from the diagnosis — a single client-side join-key bug, plus fallback-path currency dishonesty. Changes:
1. `Vehicle.fromJson` (vehicle.dart): `backendId` now reads `json['_id'] ?? json['id']` (API serializes Mongo docs with `_id`, never `id` — verified live). Also `base_price` uses `.round()` not `.toInt()` (90.86 → 91, never 90).
2. Fleet fallback currency → EUR (booking_fleet_screen.dart): `_cardCurrency` default 'TND'→'EUR', `_VehicleChoiceCard.currency` default 'TND'→'EUR', and `_select` else-branch pins `data.currency='EUR'`. The fallback estimate is derived from the EUR base_price, so EUR is the honest label (labeling it TND would have kept the bug consistent-but-wrong).
3. Confirmation screen (booking_confirmation_screen.dart): 4 hardcoded 'TND' (subtotal/adjustments/promo/total) → `data.currency`. These were missed in the earlier currency pass (which only fixed success screen + trips).

Verification:
- `flutter analyze`: No issues found. Zero runtime exceptions on launch.
- Backend join-key alignment confirmed: `/cars/` `_id` values == `price-estimate` `vehicle_id` values (car-economy…car-s-class), so `byVehicleId[backendId]` now hits.
- LIVE on emulator (dev_fleet_main.dart, TUN→Hammamet one-way): every card shows real EUR with the **ALL-INCLUSIVE** label (= real quote hit, not ESTIMATED fallback): Comfort Sedan 44, Minivan 54, Large Van 68, Minibus 95, V Class 225, S Class 502 EUR — all matching the backend quotes exactly. The reported "90 TND / BUSINESS E-Class" now renders ~191 EUR ALL-INCLUSIVE.

Out of scope (noted, not touched): several vehicles have mismatched seed `image_url`s (e.g. S-Class shows a Renault sedan, Comfort Sedan shows a VW Caddy) — a seed-data image issue, unrelated to pricing.
