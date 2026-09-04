# Carthage Transfer — Feature Status

Last updated: 2026-09-04
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
description alone.

**Screen-by-screen reference:** a separate architecture atlas documents all 27 screens (file
path, what each renders, which endpoints it calls, the state it owns, notable patterns):
<https://claude.ai/code/artifact/9bb8e8a6-c6b8-409c-a0e0-79e195c9944f>

---

## What changed since 2026-07-27

Four working sessions landed between 07-27 and 08-30. Two are committed
(`2309925` admin chrome + AVA analytics, `050bf5a` overflow/status/rewards fixes); the client
final pass, the AVA interactive cards and the notification service are **implemented, verified
and currently uncommitted**.

**Closed gaps** (all were open on 07-27):
| Was | Now |
|---|---|
| ❌ Push notifications | ✅ Local notifications + 15-min background poll (no Firebase) |
| 🔶 Password reset (no SMTP, no in-app completion) | ✅ Both endpoints wired, in-app completion, round-trip verified |
| 🔶 `POST /admin/seed` left 5 collections dirty | ✅ Clear-list extended to 12 collections |
| ⚠️ Committed Maps API key | ✅ Gitignored + `maps_config.example.dart` template |
| 🔶 Voice input untraced on device | ✅ Working, with graceful fallback where no recogniser exists |

**New this period:** AVA interactive booking cards, six-mode AVA business analytics, shared admin
chrome, manual booking-status control, spendable referral credits, fleet capacity filtering,
light-mode pass, and the removal of 279 lines of dead code.

### 2026-09-04 pass

| Change | Detail |
|---|---|
| Google sign-in removed | Placeholder button + divider + logo painter deleted; email/password only |
| Password reset hardened | Query params → JSON body (password was landing in the access log) |
| SMTP delivery wired | Off-thread send, real error logging, `SMTP_PASSWORD`/`SMTP_FROM` aliases, `.env` template |
| Notification permission fixed | `requestPermission()` had **no call site**; now wired and verified on API 36 |
| App label corrected | "DHC Transport" → "Carthage Transfer" |

Two of these were latent defects rather than missing features: the reset endpoints put the new
password in the request URL, and the Android 13+ permission was never actually requested. Both
would have looked fine in a walkthrough and failed on a real device or in a log review.

**Correction to a previously documented fact:** the Gemini free tier is **20 requests per day per
model** (`GenerateRequestsPerDayPerProjectPerModel-FreeTier`), *not* 5 per minute as the 07-27
revision recorded. This was observed repeatedly and is the single biggest demo risk — see Known
Gaps.

---

## Authentication
- ✅ **Email + password only (09-04)** — the login and signup screens carried a Google button,
  a "Or continue with" divider and a hand-drawn `_GoogleLogoPainter`. None of it was real auth:
  `onGoogle` fired a "coming soon" snackbar, and `google_sign_in` was never a dependency. The
  button, divider, painter, `_SocialButton` shell and both `_socialSoon` handlers are gone
  (~130 lines), along with three now-orphaned EN/FR strings. Confirmed on device.
- ✅ Register — `POST /auth/signup` → `register_client`, inserts user (409 on duplicate)
- ✅ Login — `POST /auth/login`, bcrypt verify, returns JWT (`build_token_response`)
- ✅ JWT storage — Flutter `auth_service.dart` persists token in `shared_preferences`
- ✅ Logout — client-side token clear; also stops the notification poll before clearing the token
- ✅ **Password reset (new 08-30)** — `POST /auth/forgot-password` stores a real token in
  `password_resets`; `POST /auth/reset-password` validates it and updates the hash. The Flutter
  screen now calls both (it previously faked success with a 700 ms delay). After requesting a
  link the screen reveals a second step — reset code + new password — so the flow completes
  **in-app** without SMTP, which is what makes it demonstrable.
  **Wire format changed 09-04.** Both endpoints previously declared bare `str` parameters, so
  FastAPI read them from the **query string** — which put the new password in the request URL,
  where uvicorn writes it verbatim into the access log. They now take JSON bodies
  (`ForgotPasswordRequest` / `ResetPasswordRequest`) and the Flutter client posts JSON.
  Email delivery is wired: `_send_reset_email` runs `smtplib` under `asyncio.to_thread` so the
  SMTP handshake cannot stall the event loop, and failures are **logged** rather than swallowed
  by a bare `except: pass` — the previous code made a dead mail server indistinguishable from a
  successful send. `Settings` accepts either spelling of the credentials
  (`SMTP_PASS`/`SMTP_PASSWORD`, `FROM_EMAIL`/`SMTP_FROM`) via `AliasChoices`, which matters
  because it forbids unknown keys and would otherwise refuse to start.
  Verified live 8/8: short password rejected (400) · bad token rejected (400) · reset succeeds ·
  login with the new password (200) · login with the old one (401) · **token reuse rejected
  (400)** · restore · login with the restored password (200).
  🔶 Remaining: `backend/.env` now carries a commented SMTP block but **no credentials**, so the
  backend logs `SMTP not configured … no email sent` and the user reads the token from the DB.
  Filling in a Gmail App Password is the only step left to deliver real mail.
  ℹ️ The response is intentionally identical for known and unknown addresses. The task asked for
  a distinct "No account with this email" error; that would let anyone enumerate registered
  accounts, and it contradicts the project's own `security_architecture.md`, so the generic
  message was kept. One line in `forgot_password` changes it if that trade is wanted.

## Client App — Booking Flow
- ✅ Booking search screen — `booking_search_screen.dart` renders a real `GoogleMap`
- ✅ Places autocomplete — `places_service.dart` → Google Places API
- ✅ Route polyline — `directions_service.dart` → Google Directions API, drawn on the map
- ✅ Real distance-based pricing engine — `POST /bookings/price-estimate`: Google Directions
  route metrics (haversine×1.3 fallback) × real per-vehicle rate cards
  (`backend/app/db/fleet_data.py` — 8 vehicles). Batch mode returns quotes for the whole fleet
  from one Directions call. Formula: `initial_fee + km × per_km + waypoint components` —
  per-hour is NOT added on distance transfers (would double-bill).
  🔶 **Economy vehicle rates remain unverified** — source PDF was truncated; seeded values are
  flagged `pricing_verified: false` and the admin Pricing card shows a "VERIFY RATES" badge.
- ✅ Vehicle selection — real EUR quotes per vehicle, one-way/return toggle that live-updates
  (cached per trip type), route metrics.
- ✅ **Capacity filtering (new 08-30)** — vehicles that cannot carry the requested party are
  hidden, not greyed out. A notice states the filter ("Showing vehicles for 4 passengers,
  3 bags — 2 too small to fit") and a distinct empty state appears when nothing fits. A vehicle
  reporting `0` seats/bags is treated as *missing capacity data*, not zero capacity, so
  incomplete records never empty the list.
- ✅ Pricing surcharges — `GET /pricing/config` layers night/weekend/last-minute + promo
- ✅ Booking confirmation screen + `RouteMapView` → `POST /bookings`
- ✅ **Rewards applied at checkout (new 08-30)** — the confirmation screen shows a "Rewards
  balance" line and the reduced total; the success screen confirms the amount spent. See Loyalty.
- 🔶 **Payment flow** — real cash-approval lifecycle, no real payment gateway:
  - `PaymentMethodScreen` sits between contact details and confirmation. Cash is a real path
    ("Requires Approval"). Card is a placeholder ("Coming Soon" → sheet redirecting to cash);
    **no card payment ever processes.**
  - Cash booking → `pending_approval` + notification to every admin. Success screen reads
    "Booking Received — pending approval".
  - Admin approves via `PATCH /admin/bookings/{id}/approve-payment` → booking flips to
    `confirmed`, client notified. Verified live.

## Client App — My Bookings
- ✅ Upcoming / past trips — `GET /bookings/history`, segmented Upcoming / History / Canceled
- ✅ Booking detail view — `GET /bookings/{id}`
- ✅ Cancel booking — `PATCH /bookings/{id}/cancel`
- ✅ Modify booking — `PUT /bookings/{id}`; 24h window enforced on both sides. The Modify/Cancel
  buttons are gated by `PricingService().canChangeBooking()` *before render*, so an action
  inside the cutoff is never offered.

## Client App — Loyalty & Promotions
- ✅ "CARTHAGE PRIVILÈGE" membership card on Profile → `GET /rewards/me`
- ✅ Promo code listing — `GET /rewards/available-promos`
- ✅ Promo application at booking — `POST /pricing/promo/validate`
- ✅ **Referral credits are now spendable (fixed 08-30)** — previously `referral_credits` was
  incremented on payout, displayed in the UI, and **never spent by anything**. Booking creation
  now draws the wallet down server-side and returns `credits_applied`; the deduction is atomic
  (`$gte` guard) so two concurrent bookings cannot spend the same balance twice.
  Verified: €43.35 booking → €38.35 charged, balance → 0, second booking correctly gets nothing.
- ✅ **Loyalty figures are consistent across admin, client and AVA (fixed 08-30)** — AVA's tool
  had its own hardcoded tier table (`0/50/150/300`) that had drifted from `rewards_service`
  (`0/30/100/200`), so AVA told clients "Silver at 50 points" while the Rewards screen said 30.
  All three now derive from one source. Verified: client `/rewards/me`, the admin loyalty view
  and AVA all report identical points/tier for the same user.
- ✅ **Private promo codes no longer leak (fixed 08-30)** — AVA listed *all* active promos with no
  owner filter, advertising other members' tier/welcome codes that the validator then refused at
  checkout. AVA's booking quote also checked expiry and usage limit but **not ownership**, so a
  foreign code would discount the quote. Both closed; 10/10 consistency tests pass.

## Client App — Destination Guide
- ✅ Listing / detail / map — `GET /destinations/recommendations/`, via
  `destination_guide_repository.dart` (the only feature with a repository layer)

## Client App — Profile
- ✅ View / edit profile — `GET /auth/me`, `PUT /auth/me` (email-uniqueness guarded)
- ✅ Profile photo — `image_picker` → `POST /auth/me/avatar`
- ✅ Settings — language (EN/FR) and theme toggles, both `ValueNotifier`-backed

## Client App — Favorites
- ✅ Saved places — `GET/POST/DELETE /favorites/`, detail sheet with notes and a photo album
- ✅ **Swipeable album (new 08-30)** — tapping a photo opens a `PageView.builder` seeded at that
  index, so the whole album swipes left/right; each page is an `InteractiveViewer` for
  pinch-zoom, with a counter shown only when there is more than one photo. Previously each photo
  had to be opened and closed individually.

## Client App — Notifications
- ✅ Notification list — `GET /notifications/`, mark-read, delete (+ undo), unread badges
- ✅ Optimistic updates with rollback — `markAllRead()` snapshots the list and restores it on
  failure
- ✅ **Out-of-app notifications (new 08-30, no Firebase)** — `flutter_local_notifications` +
  `workmanager`. A periodic task wakes ~every 15 minutes, reads the JWT from `SharedPreferences`
  in a background isolate, calls `GET /notifications/unread-count`, and posts a local
  notification when the count has **grown** since the last check (a last-seen baseline prevents
  re-announcing the same backlog every cycle).
  - New endpoint `GET /notifications/unread-count` added so the poll ships **12 bytes instead of
    7464** — the full list endpoint returns 50 documents, which is wasteful on mobile data every
    15 minutes.
  - Channel `carthage_transfer`, importance HIGH. Poll starts on login/signup, stops on logout
    *before* the token is cleared.
  - ⚠️ **Corrected 09-04.** The 08-30 revision of this file claimed the Android 13+ runtime
    permission was requested from the notifications screen. It was not: `requestPermission()`
    existed but **had no call site anywhere in `lib/`**, so on any device running API 33+ the
    OS would never have been asked and no notification could ever post. The earlier on-device
    success came from an emulator where the grant was already in place. It is now called from
    `NotificationsScreen.initState` (both roles reach that screen), and verified on an **API 36**
    emulator: permission revoked → screen opened → system dialog shown → granted, confirmed as
    `granted=true, USER_SET` in `dumpsys`.
  - **Verified on device**, not just compiled: WorkManager logged `Worker result SUCCESS` and the
    system posted `Carthage Transfer / 4 new notifications` above the "Silent" divider.
  - 🔶 Latency is bounded by Android's 15-minute floor on periodic work, and Doze can defer it
    further. It is a poll, not a push — the report should say so plainly.

## AVA — Client AI Agent
- ✅ AVA screen — "concierge lounge" ⇄ conversation state machine, once-per-session entrance
- ✅ SSE streaming chat, typing indicator, markdown bold
- ✅ **Voice input verified (08-30)** — `speech_to_text`. `initialize()` *throws* rather than
  returning false when no recogniser exists (emulator with no mic), which was previously
  uncaught; now fully guarded, degrading to a snackbar. Stopping sends the transcript. An
  `onStatus` handler resets the icon when the recogniser auto-stops.
- ✅ Booking / support (RAG) / loyalty / feedback agents
- ✅ Confirmation gate, safety check, role gate, audit log
- ✅ **Interactive booking cards (new 08-30)** — the headline UX change. Booking through chat used
  to take 6+ messages ("what date?" → "what year?" → "how many passengers?" → …). Intent is now
  detected **locally in Flutter** before sending; the chat answers with a form card, and only on
  submit does it send one complete sentence.
  - `BookingFormCard` — date/time pickers, passenger/luggage steppers, vehicle chips; route
    pre-filled from the message when stated ("from Carthage airport to Hammamet").
  - `ModifyBookingCard` — real bookings list, radio select, then progressive field reveal.
  - `CancelBookingCard` — radio select + irreversibility warning.
  - **No backend changes and no new SSE event type** — the transport stays the ordinary text
    flow. Card submission passes `allowIntentCards: false`; that bypass is load-bearing, since
    the generated sentence re-matches the booking detector and would otherwise loop.
  - Verified: intent routing 13/13 (including negatives like "What is your cancellation
    policy?"), all 5 flows on device, and the generated sentence produces a priced confirmation
    gate in ~6 s with **zero follow-up questions**.
- ✅ **Booking modification actually modifies (fixed 08-30)** — previously: select a booking →
  "confirm?" → yes → "booking updated" with **nothing changed**. Two causes: the confirmation was
  built with only a `booking_id` and no fields, and `update_trip` silently drops `None` values,
  so it wrote nothing yet returned the booking (which reads as success). The flow now asks *what*
  to change first, and the tool refuses empty or no-op updates (`no_changes_specified` /
  `values_unchanged`) and returns a diff of what actually moved.
- ✅ Chat message cards (confirmation, selection, result, info, analytics) — parsed from reply
  text; anything unrecognised falls back to a plain bubble, so a card can never break the chat
- ✅ Friendly error messages — 3 layers; raw provider text never reaches the bubble
- ✅ **Model failover (new 08-30)** — Gemini's free tier meters per day *per model*, so a single
  model's exhaustion took AVA down entirely. `CLOUD_FALLBACK` is now wired to a second model with
  its own budget, and `get_model()` returns a wrapper that fails over on `ainvoke`/`bind_tools`.
  Previously the fallback existed but was unreachable from the sub-agent paths that serve chat
  turns. Quota exhaustion now also gets its own message instead of "try again in a moment",
  which sent users into a retry loop against a limit that clears tomorrow.

## Admin App — Shared chrome (new 08-30)
- ✅ `AdminTopBar` — one header for every admin screen (title, optional back, notification bell
  with unread badge, optional action). Replaced seven bespoke app bars.
- ✅ `AdminNavBar` — delegates to the client's `PremiumClientNav` rather than duplicating the
  glass-pill animation, so both shells stay visually identical. Unread lives on the top bar's
  bell, so the nav carries no badge.

## Admin App — Dashboard
- ✅ Revenue metrics, 7-day trend, popular destinations, booking counts, open complaints
- ✅ "Pending Cash Approvals" panel → `PATCH /admin/bookings/{id}/approve-payment`
- ✅ Charts come from shared `admin_charts.dart` primitives (`GoldBarChart`, `GoldPieChart`) —
  the same ones AVA's analytics card uses, so a chart looks identical in both places. Axis steps
  snap to "nice" numbers to avoid repeated rounded labels.
- ⚠️ **Rendering trap documented:** a `BoxDecoration` combining `borderRadius` with a
  non-uniform `Border` is invalid in Flutter and fails **silently** — the card renders as an empty
  shell with no exception. Gold accent rails are drawn as a separate sliver inside a `Row`.

## Admin App — Bookings Management
- ✅ All bookings list → `TripService().listTrips()` (`GET /bookings/`); filter pills
  All / Pending Approval / Pending / Confirmed / On Route / Completed / Cancelled; client-side
  search over the loaded list
- ✅ **Manual status control (new 08-30)** — there is no driver app, so the admin is the only
  actor who can advance a booking. Each card offers the next step (**Confirm → Start trip →
  Mark as completed**) and the status chip opens a picker that can set *any* status in any order.
  Terminal states show no advance button. Verified on device: confirmed → on_route → completed.
- ✅ Booking detail view, edit sheet, delete

## Admin App — Fleet Management
- ✅ Vehicle list / add / edit / delete / toggle availability
- ✅ **Category dropdown guard** — the edit sheet builds its options as the union of known
  categories *and* whatever the car already has; `DropdownButtonFormField` asserts if the current
  value is not among its items, which previously red-screened on legacy records.

## Admin App — Pricing
- ✅ Per-vehicle rate cards with live rates; "VERIFY RATES" badge on Economy
- ✅ Edit rates → `PUT /cars/{id}` with the `pricing` object; writes a `pricing_history` record
  that feeds AVA's pricing-impact analysis
- ✅ Surcharge rules still apply server-side (`PUT /pricing/rules`); dedicated form removed from UI

## Admin App — Promotions & Loyalty
- ✅ Promotions CRUD — `GET/POST/PUT/DELETE/PATCH toggle`
- ✅ **Campaign vs member scoping (new 08-30)** — `GET /promotions/` previously dumped per-user
  reward codes into the admin's campaign list with no attribution, offering Edit on codes that
  belong to a client. The response now carries `scope` / `origin` / `owner_name`, supports
  `?scope=campaign|member`, and `PUT` is **refused with 409** on member codes since editing one
  would desync it from the tier that minted it. Suspend and revoke remain available.
- ✅ **Loyalty overview** — `GET /promotions/loyalty`: tier spread, total members, referred
  signups, awaiting-first-ride, member codes issued. Rendered as a summary card above scope tabs.
  Derived by the same rule the client uses, so the two cannot disagree.

## Admin App — Complaints
- ✅ List + filter chips + detail sheet → `GET /complaints/`, `PATCH /complaints/{id}/status`
- ✅ Dashboard stat tile + quick-action with live count

## Admin App — Suppliers / Destination Recommendations
- ✅ Both reachable via dashboard quick-actions (wired 07-27); backends fully implemented.
  Collections are empty in the demo DB, so both open to their empty states.

## Admin App — Users Management
- 🔶 Users list — backend `GET /admin/users` is real, but there is **no admin Users screen**.
- ❌ User detail — no endpoint and no screen.

## AVA — Admin AI Agent
- ✅ Admin AVA screen — operations console, deliberately dark in both app themes (pinned via a
  local `Theme`, because its message bubbles are shared with the now theme-aware client chat)
- ✅ Operations agent (state-changing, gated) / Insights agent (read-only)
- ✅ **Six-mode business analytics (reworked 08-30)** — previously every analytics question ran
  all six aggregations and returned the same blob, so answers felt repeated. Each mode now runs
  **only** its own aggregations and returns only its own KPIs and charts:

  | Mode | Charts | KPI tiles |
  |---|---|---|
  | `full_review` | 5 | Revenue MTD/YTD, Bookings MTD, Avg Booking, Completed Trips, Top Vehicle |
  | `revenue` | 2 | Revenue MTD/YTD, Avg Booking, Completed Trips |
  | `bookings` | 2 | Total, Completed, Cancelled, Pending, Confirmed |
  | `pricing` | 1 | Price Changes, Vehicles Affected, Net Delta, Changes That Lifted |
  | `seasonal` | 2 | Peak/Quiet Month, Busiest Week, Weeks Tracked |
  | `vehicles` | 2 | Top Earner, Top Revenue, Most Booked, Categories Active |

  Each mode has a focused system prompt with explicit "do NOT discuss X" clauses, and the
  narrative follows a Summary / Key findings / Recommendation contract with the real figures fed
  into the prompt. Trigger detection is deterministic (no model call) and excludes bare
  "bookings"/"pending bookings" so list queries stay list queries.
  Verified: trigger detection 8/8, live SSE end-to-end 5/5 modes, all five test prompts on device.
- ✅ Analytics card redesigned — KPI tiles, parsed narrative, compact charts with gold tooltips
  and an expand dialog, key insights
- ✅ Role enforcement + audit log

## Backend — Infrastructure
- ✅ FastAPI `create_app()`, versioned `api_router` under `/api/v1`
- ✅ MongoDB (Motor async), lifespan connect/close, indexes
- ✅ JWT auth middleware, CORS, `GET /health`
- ✅ Error handling — typed `HTTPException`; AVA path has the raw→friendly guarantee
- ✅ **`POST /admin/seed` is now a true demo-clean (fixed)** — clear-list extended from 7 to **12**
  collections (adds `complaints`, `chat_sessions`, `audit_log`, `favorites`, `pricing_history`),
  so a fresh seed no longer leaves stale test complaints and audit rows visible in the admin UI.

## AI Infrastructure
- ✅ RAG knowledge base — real documents in `ai/knowledge/` (now includes `rewards_policy.txt`)
- ✅ ChromaDB vector store + staleness guard (`source_manifest.json`, per-file SHA-256)
- ✅ Relevance floor 0.25 with low-confidence query expansion
- ✅ Gemini model router — **primary + fallback**, gated on `GOOGLE_API_KEY`
- ✅ Supervisor — classify (or Guard-0 fast path) → role gate → dispatch → safety → session write
- ✅ **Sticky follow-up routing (fixed 08-30)** — replying "2" to a booking selection landed in
  the support agent and returned a generic greeting, because the supervisor's sticky-domain guard
  only recognised "reply **yes** to confirm". A bare number carries no routable keywords, so it
  was re-classified from scratch. The guard now also covers "please reply with the number" and
  "what would you like to change?".
- ✅ **Block-list content crash (fixed 08-30)** — `booking_agent` called `.content.strip()`
  directly instead of the codebase's `extract_text()` helper. That worked only while every reply
  was a plain string; the fallback model returns **structured block lists**, and `.strip()` on a
  list threw `AttributeError`, hanging every booking turn on "preparing your answer". This was
  the actual cause of "AVA is not responding" — not quota.
- ✅ Tool registry — role-scoped, identity-bound (user_id never LLM-visible), admin tools audited
- 🔶 Evaluation harness — 28 cases; latest baseline `results_2026-06-30` (24/28 on a local-model
  substitute). **Not re-run** since; now several agent generations out of date.

## Design / UX
- ✅ Currency unified to EUR; `FontWeight.w900` eliminated (w800 ceiling); skeleton loaders
- ✅ Booking success screen as an airport-style ticket
- ✅ **Light mode pass (08-30)** — the AVA screen and booking search/map were stuck dark; both
  converted to theme-aware tokens (23 hardcoded colours). A subtler bug: `_TierPromoCard` paints
  a deliberately fixed dark gradient but used `AppColors.textMuted` for its footnote — that token
  flips to dark grey in light mode, i.e. near-invisible on near-black. Fixed with a fixed light
  muted.
  Deliberately **not** changed: status badges, the membership card, the photo lightbox and the
  admin AVA console all pair a fixed dark surface with fixed light text and are self-consistent
  in both themes.
- ✅ **AVA input double border (fixed 08-30)** — the app's global `inputDecorationTheme` sets
  `enabledBorder`/`focusedBorder`; `border: InputBorder.none` only overrides the *fallback*, so
  the theme kept painting a second outline inside the pill. Every border state now cleared.
- ✅ **Overflow fixes** — promo cards (long generated codes + raw ISO expiry) and the analytics
  KPI tile
- ✅ **Dead code removed (08-30)** — `_ExploreTab` / `_ExploreFleetCard` / `_SpecChip` were fully
  implemented but never mounted (leftover from a six-tab layout). 279 lines + 2 orphaned imports
  deleted; `client_shell.dart` 5157 → 4876.

---

## Known Gaps & TODOs
- ❌ **Real payment gateway** — no Stripe/PayPal integration. Card payment is a UI placeholder
  that redirects to cash; only the cash-approval lifecycle is real.
- ❌ **Admin Users screen** — backend `GET /admin/users` exists; no Flutter UI.
- 🔶 **Notifications are polled, not pushed** — 15-minute Android floor, and Doze can defer
  further. Describe it accurately in the report; do not call it push.
- 🔶 **Password-reset email** — endpoints, JSON contract, delivery code and logging are all in
  place; `backend/.env` just has no SMTP credentials yet, so nothing is actually sent. Fill in
  `SMTP_HOST/SMTP_USER/SMTP_PASSWORD` (Gmail needs a 16-char App Password) to enable it.
- 🔶 **Economy vehicle pricing** — seeded from a truncated source PDF; flagged
  `pricing_verified: false` with a "VERIFY RATES" badge. Data issue, not code.
- 🔶 **Eval baseline is stale** — last full run 06-30 on a local-model substitute, several agent
  generations ago. A production re-run would cost ~28 Gemini calls (see quota below).
- ⚠️ **Gemini free tier = 20 requests/day, per model** — the single biggest demo risk. An
  analytics turn costs 2 calls (classify + analyst). With failover across two models the
  practical ceiling is ~40 calls/day. **Enable billing before the defence**, or rehearse with a
  second API key. Resets at midnight **Pacific**, not local.
- 🔶 **App icon still default** — the launcher label is now **"Carthage Transfer"** (fixed 09-04;
  confirmed in the system permission dialog), but the icon is still the stock Flutter logo.
  Replacing `@mipmap/ic_launcher` is the last branding step.
- 🔶 **AVA modify exposes a raw booking reference** — the "what would you like to change?" message
  prints `booking-5eeed90a…` so the model can target the right record. It works, but contradicts
  the app's own "never expose raw IDs" rule and looks unpolished.
- 🔶 **Cosmetic:** the booking card's generated sentence says "1 bags". Harmless (the backend
  parses it), but it reads oddly.
- ℹ️ **Analytics are data-sparse** — real aggregations, but only meaningful once bookings
  accumulate.
- ℹ️ **Uncommitted work** — the client final pass, AVA interactive cards, notification service,
  dead-code removal and forgot-password wiring are all verified but **not yet committed**.

## Report Sections Written (`report/`)
- `introduction.md`
- `bug_fix_log.md`
- `evaluation_methodology.md`
- `security_architecture.md`

## Verification status
`flutter analyze` **clean** (verified with an explicit `dart analyze lib` — the cached
full-project run has served stale results in this repo). Debug APK builds for both `android-x64`
(emulator) and `android-arm64` (physical device). Backend imports and graphs compile.

**Tested live this period:** AVA analytics 5/5 modes end-to-end · booking-card flow on device
(all 5 scenarios) · rewards integration 15/15 · admin/client/AVA loyalty consistency 10/10 ·
booking status chain confirmed→on_route→completed · password-reset round-trip incl. token reuse
rejection · notification poll posting a real system notification · promo scope + 409 edit guard.
