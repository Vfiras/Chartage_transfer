# Carthage Transfer — Feature Status

Last updated: 2026-07-27
Stack: Flutter (client + admin) + FastAPI + MongoDB (Motor async) + LangGraph + Gemini 2.5 Flash

## Legend
✅ Real & working — backed by real code, real DB, real API
🔶 Partial — exists but has a known gap (described inline)
❌ Static/placeholder — hardcoded or not connected

Basis: 15 API routers wired in `api.py`; real MongoDB operations across 15 endpoint files
(`admin`, `analytics`, `assistant`, `auth`, `bookings`, `cars`, `complaints`, `config`,
`destinations`, `favorites`, `notifications`, `pricing`, `promotions`, `rewards`, `suppliers`);
real API-client calls across the Flutter services. Every feature marked ✅ points to a real
route + DB op or a real service call — verified by reading the endpoint/screen source, not by
description alone. This revision folds in the 2026-07-07 → 2026-07-09 completion sessions
(real fleet pricing, cash-payment approval flow, AVA business analytics, complaints management,
design elevation pass) that the 07-06 version of this file predated.

**2026-07-27 verification session:** wired the two unreachable admin screens (Suppliers,
Recommendation Management) into the dashboard quick-actions; ran the full booking lifecycle live
against the running backend (login → cars → batch price-estimate via real Google Directions →
create cash booking → client+admin notifications → history → admin overview → approve-payment →
confirm → cancel → complaint create/list/status) — **13/13 steps passed**; ran the 5 AVA
scenarios (RAG policy, upcoming trips, loyalty, admin business review with analytics event,
client role-gate refusal) — all pass in isolation (one back-to-back run hit the 5-req/min Gemini
free-tier cap, fallbacks verified); `flutter analyze` **clean**; debug **APK builds** (exit 0);
`docker compose config` validates and `docker compose build` runs (Docker Desktop).

---

## Authentication
- ✅ Register — `POST /auth/signup` → `register_client`, inserts user (409 on duplicate)
- ✅ Login — `POST /auth/login`, bcrypt verify, returns JWT (`build_token_response`)
- ✅ JWT storage — Flutter `auth_service.dart` persists token in `shared_preferences`
- ✅ Logout — client-side token clear (no server session to invalidate; correct for JWT)
- 🔶 Password reset — `POST /auth/forgot-password` stores a real token in `password_resets` and
  `POST /auth/reset-password` really validates the token + updates the hash. Gaps: (1) email
  delivery is best-effort and SMTP is unset by default in `.env`, so no email is actually sent
  in the demo; (2) the reset URL targets `app_base_url` (web), so there is no in-app deep-link
  to complete the reset.

## Client App — Booking Flow
- ✅ Booking search screen — `booking_search_screen.dart` renders a real `GoogleMap`
- ✅ Places autocomplete — `places_service.dart` → Google Places API (real key in `maps_config.dart`)
- ✅ Route polyline — `directions_service.dart` → Google Directions API, drawn on the map
- ✅ Real distance-based pricing engine — `POST /bookings/price-estimate`: Google Directions
  route metrics (haversine×1.3 fallback) × real per-vehicle rate cards
  (`backend/app/db/fleet_data.py` — 8 real vehicles: Economy, Comfort Sedan, Minivan, Large Van,
  Minibus, E Class, S Class, V Class — each with initial fee, per-km, per-hour, per-waypoint,
  return rates, sourced from the live site's booking-system PDFs). Batch mode returns quotes for
  the whole fleet from one Directions call. Formula: `initial_fee + km × per_km + waypoint
  components` — per-hour is NOT added on distance transfers (would double-bill).
  🔶 **Economy vehicle rates are unverified** — the source PDF was truncated; seeded values are
  flagged `pricing_verified: false` and the admin Pricing card shows a "VERIFY RATES" badge.
- ✅ Vehicle selection — `booking_fleet_screen.dart` shows real EUR quotes per vehicle
  ("ALL-INCLUSIVE" badge), a one-way/return toggle that live-updates prices (cached per trip
  type), and route metrics (km + drive time). Falls back to a local rules-based TND estimate
  ("ESTIMATED" badge) only if coordinates are missing or the endpoint fails.
- ✅ Pricing surcharges — `pricing_service.dart` → `GET /pricing/config` layers night/weekend/
  last-minute surcharges + promo on top of the real base price
- ✅ Booking confirmation screen — `booking_confirmation_screen.dart` + `RouteMapView`
  (interactive map + Directions polyline) → `POST /bookings`
- 🔶 **Payment flow** — real cash-approval lifecycle, no real payment gateway:
  - `PaymentMethodScreen` sits between contact details and confirmation. Cash card is a real,
    selectable path ("Requires Approval" badge). Card is a placeholder ("Coming Soon" badge →
    bottom sheet redirecting to cash); **no card payment ever actually processes.**
  - Booking docs carry `payment_method` (`cash`/`card`) + `payment_status`
    (`pending_approval`/`approved`). Cash booking → `pending_approval` + a notification is
    pushed to every admin user. Success screen for cash reads "Booking Received — pending
    approval", not "Confirmed".
  - Admin approves via `PATCH /admin/bookings/{id}/approve-payment` → booking flips to
    `confirmed`, client gets a "Booking confirmed" notification. Verified live end-to-end
    (2026-07-08 session).

## Client App — My Bookings
- ✅ Upcoming trips list — `trip_service.dart` → `GET /bookings/`
- ✅ Past trips list — → `GET /bookings/history`
- ✅ Booking detail view — → `GET /bookings/{id}`
- ✅ Cancel booking — → `PATCH /bookings/{id}/cancel`
- ✅ Modify booking — `_ModifyBookingScreen` pre-loads fields → `PUT /bookings/{id}`; 24h
  modification window enforced client- and server-side; success snackbar on save

## Client App — Loyalty & Promotions
- ✅ Points balance and tier display — now surfaced as a **"CARTHAGE PRIVILÈGE" membership
  card** on the Profile tab (dark-lacquer card, tier chip, points hero, gold progress, rides-to-
  next-tier) → `reward_service.dart` → `GET /rewards/me`; replaces the old buried "Rewards" row.
  Guests excluded.
- ✅ Promo code listing — → `GET /rewards/available-promos`
- ✅ Promo code application at booking — `POST /pricing/promo/validate` applies discount to the quote

## Client App — Destination Guide
- ✅ Destination listing — `destination_guide_repository.dart` → `GET /destinations/recommendations/`
- ✅ Destination detail — `destination_detail_screen.dart` from the fetched recommendation
- ✅ Map on detail screen — `GoogleMap` via `route_map_view` / `tn_locations`

## Client App — Profile
- ✅ View profile — `GET /auth/me` → `build_user_payload`
- ✅ Edit profile — `edit_profile_screen.dart` → `PUT /auth/me` (email-uniqueness guarded)
- ✅ Profile photo — `image_picker` → `POST /auth/me/avatar` (validated, stored, old avatar
  deleted); avatar now also renders beside the user's own bubbles in the AVA chat

## Client App — Notifications
- ✅ Notification list — `notification_service.dart` → `GET /notifications/`, mark-read
  (`PATCH .../read`, `/read-all`), delete (+ undo); unread badges on both the Alerts tab and the
  Bookings-tab bell
- ❌ Push notifications — no `firebase_messaging`/FCM in `pubspec.yaml`. In-app list only;
  nothing is pushed to the device.

## AVA — Client AI Agent
- ✅ AVA screen — redesigned "concierge lounge" (2026-07-09): lounge⇄conversation state machine,
  horizontal quick-action chips with natural first-message labels, once-per-session entrance
  animation — `assistant_screen.dart`
- ✅ Chat interface (SSE streaming, typing indicator, markdown bold) — `assistant_api_service.dart`
  streams `POST /assistant/chat`, parses `data:` events, stops on `done`/`error`
- ✅ Voice input (speech-to-text) — `speech_to_text: ^7.0.0`, `SpeechToText()` in
  `assistant_screen.dart` (needs mic permission; not traced end-to-end on a physical device)
- ✅ Booking agent — `booking_agent.py`: trip history, real-fleet vehicle recommendation
  (seats≥pax filter, price-sorted, EUR estimates), create/modify/cancel (4-node internal router)
- ✅ Support agent (RAG) — `support_agent.py` over the 5-doc knowledge base; low-confidence query
  expansion added for "airport assistance"-style queries that miss the 0.25 relevance floor
- ✅ Loyalty agent — `loyalty_agent.py`: points, tier, promos (+ deterministic template fallback)
- ✅ Feedback agent — `feedback_agent.py` → `submit_claim` writes a complaint
- ✅ Confirmation gate (propose → yes/no → execute) — `run_with_confirmation` in `shared.py`
- ✅ Safety check node — supervisor `safety` node
- ✅ Role gate (client cannot reach admin tools) — supervisor `role_gate` + role-scoped tool registry
- ✅ Audit log — admin tool calls wrapped by `_wrap_with_audit` → `audit_log` collection
- ✅ Chat message cards (confirmation, selection, result, info, **analytics**) —
  `ava_card_parser.dart` + card widgets; gold left-accent on AVA bubbles
- ✅ Friendly error messages — **3 layers**: (1) `invoke_with_fallback` collapses every model
  failure to a friendly RuntimeError; (2) `_run()` catches any sub-agent exception; (3) the whole
  supervisor-graph construction is wrapped, so even a graph-build failure yields a friendly SSE
  event instead of a raw 500. Raw error text never reaches the bubble (re-verified 2026-07-07).
- ✅ Model routing — **Gemini only**, flat. Local/Ollama tier fully removed.

## Admin App — Dashboard
- ✅ Revenue metrics — `admin_dashboard_screen.dart` → `GET /analytics/dashboard` + `GET /admin/overview`
- ✅ 7-day booking trend — computed in analytics/overview endpoints
- ✅ Popular destinations — computed server-side from bookings
- ✅ Booking counts, open-complaints count — from `GET /admin/overview`
- ✅ **"Pending Cash Approvals" section** — gold-bordered panel with count badge, horizontal
  scrollable cards (client, route, date, vehicle, price) → approve sheet → `PATCH
  /admin/bookings/{id}/approve-payment`, card disappears on approval

## Admin App — Bookings Management
- ✅ All bookings list — `admin_bookings_screen.dart` → `GET /admin/bookings`; filter chips
  All / **Pending Approval** / Pending / Confirmed / On Route / Completed / Cancelled
- ✅ Booking status update — `booking_edit_sheet.dart` → `PATCH /bookings/{id}/status`
- ✅ Booking detail view — `admin_booking_details_screen.dart`

## Admin App — Fleet Management
- ✅ Vehicle list — `admin_cars_screen.dart` → `GET /cars/all`
- ✅ Add/edit/delete vehicle — `POST /cars/`, `PUT /cars/{id}`, `DELETE /cars/{id}`
- ✅ Toggle availability — `PATCH /cars/{id}/availability`

## Admin App — Pricing (per-vehicle rate editor, replaces the old surcharge form)
- ✅ Per-vehicle rate cards — `admin_pricing_screen.dart` lists every fleet vehicle with live
  rates (initial/return/per-km/per-hour/waypoint); "VERIFY RATES" badge on Economy
- ✅ Edit rates — tap → editor sheet, one input per pricing parameter → `PUT /cars/{id}` with the
  `pricing` object (syncs `base_price` to the initial fee); writes a `pricing_history` record
  (feeds AVA's pricing-impact analytics)
- ✅ Surcharge rules (night/weekend/last-minute) still exist and apply server-side —
  `PUT /pricing/rules` — but the old dedicated surcharge-rules form was removed from the UI

## Admin App — Users Management
- 🔶 Users list — backend `GET /admin/users` is real, but there is **no admin Users screen** in
  Flutter (only dashboard count + AVA insights agent reads users). No dedicated UI.
- ❌ User detail — no endpoint and no screen.

## Admin App — Suppliers
- ✅ Suppliers list / Add/edit/delete/toggle — backend fully implemented (`suppliers.py`:
  GET/POST/PUT/PATCH status/DELETE) and `admin_suppliers_screen.dart` is built. **Now reachable
  (2026-07-27):** wired as a "Suppliers" quick-action on the admin dashboard
  (`admin_dashboard_screen.dart` → `onOpenSuppliers` → `AdminShell._pushSuppliers` pushes
  `AdminSuppliersScreen`). No longer dead code. NB: the `suppliers` collection is empty in the
  demo DB, so the screen opens to its empty state until suppliers are added.

## Admin App — Promotions
- ✅ Promotions list — `admin_promotions_screen.dart` (pushed from dashboard) → `GET /promotions/`
- ✅ Add/edit/delete/toggle — `POST`, `PUT /{id}`, `DELETE /{id}`, `PATCH /{id}/toggle`

## Admin App — Complaints (new since 07-06)
- ✅ Complaints list — `admin_complaints_screen.dart` (pushed from dashboard) → `GET /complaints/`,
  filter chips All/Open/In review/Resolved, status badges, detail sheet (user/booking/message/
  timestamp + status selector)
- ✅ Update complaint status — `PATCH /complaints/{id}/status` (admin-only; open/in_review/resolved;
  400 on invalid status, 403 for non-admin) — this closes the gap the 07-06 version of this file
  flagged as missing
- ✅ Dashboard "Open complaints" stat tile + quick-action with live count

## Admin App — Destination Recommendation Management
- ✅ `RecommendationManagementScreen` (route `/admin/recommendations`, registered in
  `app_router.dart`). **Now reachable (2026-07-27):** wired as a "Destinations" quick-action on
  the admin dashboard (`onOpenRecommendations` → `AdminShell._pushRecommendations` →
  `Navigator.pushNamed(AppRoutes.recommendationManagement)`). NB: the `recommendations`
  collection is empty in the demo DB, so the screen opens to its empty state until entries exist.

## Admin App — Analytics
- ✅ Dashboard analytics endpoint — `GET /analytics/dashboard`
- ✅ Admin overview endpoint — `GET /admin/overview`

## AVA — Admin AI Agent
- ✅ Admin AVA screen — `admin_assistant_screen.dart`, reached from `admin_profile_screen.dart`
- ✅ Operations agent — `operations_agent.py`: fleet, pricing, suppliers, promotions (state-changing, gated)
- ✅ Insights agent — `insights_agent.py`: analytics, user list, booking list (read-only)
- ✅ **Business analytics / BI pipeline (new since 07-06)** — admin message → supervisor "Guard 0"
  (deterministic phrase detection, skips the Gemini classify call for analysis requests) →
  insights agent fast path → `run_business_analysis` tool → `analytics_service.py` (6 real
  MongoDB aggregation methods: revenue by month/category, booking volume trend, seasonal
  analysis, pricing-impact analysis via the `pricing_history` collection, KPI summary) →
  deterministic chart specs/KPIs/insights + **one** dedicated Gemini call for the narrative
  (degrades to a deterministic summary on quota failure, never crashes the turn) → SSE
  `"analytics"` event → Flutter `AnalyticsCard` (`fl_chart`: line/area/bar/pie, KPI tiles with
  trend arrows, gold-dot insight bullets). Verified live: "Give me a full business review" and
  "How did our pricing changes affect bookings?" both returned numerically-accurate,
  DB-grounded narratives.
- ✅ Role enforcement — admin JWT required; `role_gate` + `require_admin`; client JWT cannot reach admin tools
- ✅ Audit log for admin tool calls — every admin tool wrapped → `audit_log`

## Backend — Infrastructure
- ✅ FastAPI app structure — `main.py` `create_app()`, versioned `api_router` under `/api/v1`
- ✅ MongoDB connection (Motor async) — `core/database.py`, lifespan connect/close, indexes in `db/indexes.py`
- ✅ JWT authentication middleware — `core/deps.py` (`get_current_user`, `require_admin`), `core/security.py`
- ✅ CORS configuration — configured from `allowed_origins`
- ✅ Health endpoint — `GET /health` → `{"status":"ok"}`
- ✅ Error handling — endpoints raise typed `HTTPException`; AVA path has the raw→friendly guarantee

## AI Infrastructure
- ✅ RAG knowledge base — 5 real documents in `ai/knowledge/` (`faq`, `pricing_policy`,
  `terms_and_conditions`, `vehicles`, `destinations`)
- ✅ ChromaDB vector store — `ai/vectorstore/chroma.sqlite3` (~648 KB, rebuilt 2026-07-08) + collection dir
- ✅ Staleness guard — `source_manifest.json` (per-file SHA-256); `log_freshness_on_startup()` warns if KB changed since last build
- ✅ Relevance floor — 0.25 confidence threshold, with low-confidence query expansion (2026-07-07 fix) for queries that miss it (e.g. "airport assistance")
- ✅ Gemini 2.5 Flash model router — `model_router.py`, flat routing, gated on `GOOGLE_API_KEY`
- ✅ Supervisor — `supervisor.py`: intent classification (or Guard-0 fast path) → role gate → dispatch → safety → session write
- ✅ Tool registry — `tool_registry.py`: role-scoped, identity-bound (user_id never LLM-visible), admin tools audited
- ✅ Evaluation harness — `evaluation/`: 28 test cases + `run_eval.py`; latest baseline
  `results_2026-06-30_10-29-26.md` (24/28 as-run on a local-model substitute for quota reasons;
  not re-run against production Gemini since)

## Design / UX (new since 07-06 — "design elevation pass", 07-08/07-09)
- ✅ Currency unified to EUR across receipts/trips/promos/confirmation (a real bug was found and
  fixed: a client-side `_id`-vs-`id` join-key mismatch was silently discarding real EUR quotes
  and falling back to a truncated, mislabeled "90 TND" estimate — root-caused and fixed 2026-07-09)
- ✅ `FontWeight.w900` eliminated app-wide (w800 ceiling), one `LuxuryCta` button spec, skeleton
  loaders replace spinners on fleet/trips/admin-bookings/complaints/pricing
- ✅ Booking success screen redesigned as an airport-style ticket (route code, perforated fold, self-drawing check)
- ✅ Destinations screen filter chips now actually filter (previously decorative)

---

## Known Gaps & TODOs
- ❌ **Real payment gateway** — no Stripe/PayPal/card processor integration. Card payment is a
  UI placeholder that redirects to cash; only the cash-approval lifecycle is real.
- ❌ **Push notifications** — no FCM/firebase; notifications are in-app list only.
- ❌ **Admin Users screen** — backend `GET /admin/users` exists; no Flutter UI.
- ✅ ~~**Admin Suppliers screen** — unreachable~~ — **FIXED 2026-07-27**: wired as a dashboard quick-action.
- ✅ ~~**Admin Recommendation Management screen** — unreachable~~ — **FIXED 2026-07-27**: wired as a dashboard quick-action.
- 🔶 **Password reset end-to-end** — backend token flow is real, but SMTP is unset (no email sent) and there is no in-app deep-link to finish the reset.
- 🔶 **Economy vehicle pricing** — seeded from a truncated source PDF; flagged `pricing_verified: false`, needs a human to read the exact rates from the WordPress admin. (Data issue, not code: the `pricing_verified: false` flag and the "VERIFY RATES" badge both render correctly — verified live via `GET /cars/all` on 2026-07-27.)
- 🔶 **`POST /admin/seed` is not a full demo-clean** — it clears only 7 collections (users, cars, bookings, destinations, promotions, pricing_rules, notifications) and **leaves complaints, chat_sessions, audit_log, favorites, pricing_history untouched**. As of 2026-07-27 the DB carries ~63 stale complaints (58 from orphan test users like `test-client-ava-001`/`test-stability-*`, mostly "driver was 30 minutes late" fixtures) + ~124 audit-log rows + ~15 chat_sessions from AI test runs. These would show in the admin Complaints screen / "open complaints" stat during a demo. Fix option: extend the seed clear-list, or manually clear those collections before a demo. Nothing was deleted in this session (report-only per instructions).
- ⚠️ **Committed Maps API key** — `maps_config.dart` contains a live Google Maps key in source. Security concern (rotate / move to a gitignored config), not a functional gap.
- ℹ️ **Free-tier Gemini quota** — the free tier caps `gemini-2.5-flash` at **5 requests/minute** (`generate_content_free_tier_requests`), observed live 2026-07-27: running the 5 AVA test scenarios back-to-back tripped a 429/RESOURCE_EXHAUSTED on the booking agent (multiple LLM calls per turn). Each scenario passes when run in isolation, and the deterministic fallbacks (booking `_vehicle_template`, analytics deterministic insights) fire correctly on quota exhaustion. Paid billing removes the cap.
- ℹ️ **Analytics charts are data-sparse in the demo DB** — real aggregations, but only meaningful once bookings accumulate (seeded DB currently has 1 completed booking).
- ℹ️ **Static seed/preview data** — `lib/data/*.dart` and several `dev_*_main.dart` preview entrypoints are dev-only scaffolding, not used by the live client flows.

## Report Sections Written (`report/`)
- `introduction.md`
- `bug_fix_log.md`
- `evaluation_methodology.md`
- `security_architecture.md`

## Features flagged with genuine uncertainty (need on-device/emulator re-verification)
- **Voice input** — package + `SpeechToText()` instance are real; full mic→transcript→send wiring not traced end-to-end on a physical device.
- **7-day trend / popular destinations** — endpoints aggregate real data; numbers are correct against the small seeded DB but haven't been checked against a larger dataset.
- **Password-reset completion** — token flow is real; whether the reset field actually round-trips through login has not been re-tested since 07-06.
- **Eval baseline currency** — the last full 28-case run (06-30) used a local-model substitute for some cases to conserve Gemini quota; a production-Gemini re-run has not happened since the 07-07→07-09 agent changes (recommend_vehicle, RAG query expansion, analytics fast path).
