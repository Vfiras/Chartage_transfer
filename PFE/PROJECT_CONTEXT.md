# Carthage Transfer — Project Context & Architecture Reference

> **Purpose of this document:** Complete technical and functional reference for AI-assisted development planning. Covers every screen, API endpoint, database schema, and implementation detail of the current codebase as of 2026-07-14 (re-audited against source: real distance-based pricing engine, cash-payment approval flow, admin complaints management, and AVA business analytics were all added 2026-07-07→07-09 and are reflected below; items previously marked unverified have been confirmed or corrected by reading the actual code).

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Repository Structure](#3-repository-structure)
4. [Authentication & Authorization](#4-authentication--authorization)
5. [Client Mobile App](#5-client-mobile-app)
6. [Admin Dashboard](#6-admin-dashboard)
7. [Backend API — Complete Endpoint Reference](#7-backend-api--complete-endpoint-reference)
8. [Database — Collections & Schemas](#8-database--collections--schemas)
9. [Business Logic & Rules](#9-business-logic--rules)
10. [AI Assistant (AVA)](#10-ai-assistant-ava)
11. [Loyalty & Rewards System](#11-loyalty--rewards-system)
12. [Destination Guide & Recommendations](#12-destination-guide--recommendations)
13. [Notifications System](#13-notifications-system)
14. [Supplier Management](#14-supplier-management)
15. [Dynamic Pricing Engine](#15-dynamic-pricing-engine)
16. [Promotions System](#16-promotions-system)
17. [Theming, Localization & UX](#17-theming-localization--ux)
18. [Infrastructure & Deployment](#18-infrastructure--deployment)
19. [Known Gaps & Future Work](#19-known-gaps--future-work)

---

## 1. Project Overview

**Carthage Transfer** (internal codename: DHC Transport) is a full-stack luxury private transfer booking platform for Tunisia. It connects clients with a premium fleet (Standard, VIP, Luxury, Van) through a Flutter mobile app backed by a FastAPI/MongoDB REST API.

### Core Value Proposition
- Digitizes phone-based private transport booking in Tunisia
- Transparent, rule-based dynamic pricing (night/weekend/seasonal/last-minute surcharges)
- Full client self-service: book, modify, cancel, track status
- Loyalty rewards program (points → tiers → promo codes)
- AI conversational assistant (AVA) for booking, support, and trip management
- Operator back-office: fleet, bookings, pricing, suppliers, promotions, analytics

### User Roles
| Role | Description |
|---|---|
| `client` | Registered customer. Manages own bookings, rewards, favorites, profile. |
| `admin` | Operator/staff. Full CRUD on all resources + analytics + configuration. |
| Guest | Unauthenticated user. Can book by email only (no account required). |

---

## 2. Tech Stack

### Mobile Frontend
| Technology | Version / Notes |
|---|---|
| Flutter | 3.3+ |
| Dart | Current stable |
| Material Design 3 | Custom gold/dark theming |
| Google Fonts | Montserrat |
| `http` | REST API client |
| `shared_preferences` | Session persistence, theme, language |
| `image_picker` | Profile avatar upload |
| `intl` | Date/time formatting, i18n |
| `speech_to_text` | Voice input for AVA |
| `fl_chart` | Charts (line/area/bar/pie) for AVA's admin Business Analytics card |

> Not present in `pubspec.yaml` (verified 2026-07-14): no `firebase_messaging`/FCM, no payment
> SDK (`flutter_stripe` or similar). Push notifications and real card payment are not implemented.

### Backend
| Technology | Version / Notes |
|---|---|
| Python | 3.11+ |
| FastAPI | Async REST framework |
| Uvicorn | ASGI server |
| Pydantic v2 | Data validation + DTOs |
| `pydantic-settings` | Config from environment variables |
| `python-jose` | JWT generation and validation |
| `passlib` / `bcrypt` | Password hashing |
| `python-multipart` | File upload handling |
| `motor` | Async MongoDB driver |
| `pymongo` | Sync driver for scripts/seeding |

### Database
| Technology | Notes |
|---|---|
| MongoDB 7 | Document store, no fixed schema enforced at DB level |
| Motor | Used for all async FastAPI operations |

### AI / AVA Assistant
| Technology | Notes |
|---|---|
| LangChain | LLM orchestration + tool chaining |
| LangGraph | Stateful multi-step agent graph |
| RAG | Vector store over company policy docs |
| Embeddings + Vector Store | Semantic search over knowledge base |
| Speech-to-Text | Voice-to-text pipeline for mobile |
| Claude / OpenAI | Underlying LLM (configurable) |

### Infrastructure
| Technology | Notes |
|---|---|
| Docker | Containerization |
| Docker Compose | API + MongoDB orchestration |

---

## 3. Repository Structure

```
PFE/
├── DHC_transport/                  # Flutter mobile application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── routing/            # Route definitions (app_routes.dart)
│   │   │   ├── services/           # All service classes (HTTP, auth, etc.)
│   │   │   └── theme/              # ThemeService, color constants
│   │   ├── features/
│   │   │   ├── admin/
│   │   │   │   └── presentation/   # All admin screens
│   │   │   ├── destination_guide/
│   │   │   │   ├── data/           # Repository + API calls
│   │   │   │   └── presentation/   # Screens + widgets
│   │   │   ├── notifications/
│   │   │   │   └── presentation/   # Notification screen + widgets
│   │   │   └── recommendations/
│   │   │       └── presentation/   # Admin recommendation management
│   │   └── screens/
│   │       ├── auth/               # Login, signup, forgot-password
│   │       ├── client/             # ClientShell (main tab host)
│   │       └── *.dart              # Booking, vehicles, services, profile, assistant
│   ├── android/                    # Android-specific config
│   ├── windows/                    # Windows build config
│   └── pubspec.yaml                # Flutter dependencies
│
├── backend/
│   └── app/
│       ├── api/v1/
│       │   ├── api.py              # Router aggregator
│       │   └── endpoints/          # One file per resource
│       │       ├── auth.py
│       │       ├── bookings.py
│       │       ├── cars.py
│       │       ├── pricing.py
│       │       ├── promotions.py
│       │       ├── favorites.py
│       │       ├── destinations.py
│       │       ├── admin.py
│       │       ├── notifications.py
│       │       ├── suppliers.py
│       │       ├── rewards.py
│       │       ├── analytics.py
│       │       └── config.py
│       ├── core/
│       │   ├── config.py           # Settings (env vars, MongoDB URI, JWT secret)
│       │   └── security.py         # JWT helpers, password hashing
│       ├── db/                     # MongoDB connection
│       └── main.py                 # FastAPI app entry point
│
├── PRESENTATION.md                 # User-facing feature summary (French)
└── PROJECT_CONTEXT.md              # This file
```

---

## 4. Authentication & Authorization

### Flow
1. Client POSTs `email + password` to `POST /api/v1/auth/login`
2. Backend validates credentials, returns `access_token` (JWT) + `role` + user profile
3. Flutter stores token in `SharedPreferences`
4. Every subsequent request includes `Authorization: Bearer {token}` header
5. Backend FastAPI dependency `get_current_user` decodes JWT, fetches user from DB
6. Role-specific dependencies: `require_client` (client or admin), `require_admin` (admin only)

### JWT Configuration
- Secret: from `config.py` (`SECRET_KEY` env var)
- Algorithm: HS256
- Expiry: configurable (default ~24h)

### Password Reset Flow
1. `POST /auth/forgot-password` — backend creates a 1-hour reset token stored in `password_resets` collection, sends email if SMTP configured
2. `POST /auth/reset-password` — validates token, updates hashed password, deletes token

### Guest Booking
- Users can book without an account by providing `guest_email` and `guest_phone`
- `is_guest: true` flag stored on booking
- No profile, favorites, or rewards access for guests

---

## 5. Client Mobile App

### App Routing
Defined in `DHC_transport/lib/core/routing/app_routes.dart`:

| Route | Screen | Notes |
|---|---|---|
| `/auth` | `AuthWelcomeScreen` | Landing: login or signup CTA |
| `/login` | `LoginScreen` | Email + password |
| `/signup` | `SignupScreen` | Name, email, phone, password |
| `/forgot-password` | `ForgotPasswordScreen` | Email input → reset link |
| `/client` | `ClientShell` | Main authenticated app shell |
| `/admin` | `AdminShell` | Admin dashboard shell |
| `/destination-guide` | `DestinationGuideScreen` | Browse Tunisia destinations |
| `/admin/recommendations` | `RecommendationManagementScreen` | Admin: manage recommendations |
| `/assistant` | `AssistantScreen` | AVA AI chat interface |

### ClientShell — Bottom Navigation Tabs
File: `DHC_transport/lib/screens/client/client_shell.dart`

The client app uses a custom **glass-pill + gold-expansion** bottom navigation bar (considered final, do not redesign).

| Tab Index | Label | Key Features |
|---|---|---|
| 0 | Home | Hero greeting (time-aware), "Book Now" CTA, fleet preview, favorite places quick-access |
| 1 | Bookings | Upcoming / past / cancelled trips, modify/cancel actions |
| 2 | Saved | Favorite locations (home, work, airport, custom) |
| 3 | Alerts | Notification center with unread badge |
| 4 | Profile | Account info, avatar, theme toggle, language switch, logout |

---

### Screen Breakdown — Client

#### `booking_search_screen.dart`
- Pickup and destination location fields with city autocomplete (fetched from `/config/cities`)
- Trip type selector: One-way / Round-trip
- Date + time pickers with validation (minimum advance notice enforced)
- Passenger count (1–8) and luggage count selectors
- Passes all parameters forward to vehicle selection screen

#### Fleet / Vehicle Selection — `booking_fleet_screen.dart`
- Fetches the real fleet from `GET /cars` (availability=true) — 8 real vehicles (Economy, Comfort
  Sedan, Minivan, Large Van, Minibus, Mercedes E/S/V Class)
- Fetches a **real distance-based batch quote** from `POST /bookings/price-estimate` (one Google
  Directions call for the whole fleet) and shows the actual EUR price per vehicle with an
  "ALL-INCLUSIVE" badge, plus route metrics (km + drive time) and a one-way/return toggle that
  live-updates every card (quotes cached per trip type)
- Falls back to a local rules-based TND estimate ("ESTIMATED" badge) only if pickup/destination
  coordinates are missing or the price-estimate call fails
- Selecting a vehicle stores the real quoted total as the base price; the confirmation flow then
  layers night/weekend/last-minute surcharges and any promo code on top of that real base
  (`PricingService.estimateFromBase`)

#### `contact_confirmation_screen.dart`
- Collects/reviews contact details (name, phone, email) before payment

#### `payment_method_screen.dart`
- Presents two payment options: **Cash** ("Requires Approval" badge — a real, selectable path)
  and **Card** ("Coming Soon" badge — tapping opens a bottom sheet that redirects to Cash; no
  card payment ever actually processes). This is the only payment surface in the app; there is
  no payment gateway integration.

#### `booking_confirmation_screen.dart`
- Full summary: pickup, destination, date/time, vehicle, passenger/luggage counts, an interactive
  `RouteMapView` (Google Directions polyline between the resolved pickup/destination coordinates)
- Promo code field: validates against `POST /pricing/promo/validate`
- Shows discount applied and final price, all in the vehicle's real currency (EUR)
- "Confirm Booking" button creates the booking via `POST /bookings` with the chosen `payment_method`

#### `booking_success_screen.dart`
- Redesigned (2026-07-08) as an airport-style ticket: route shown as an airport-code pair
  (e.g. TUN → HAM), perforated-fold visual, vehicle plate, self-drawing gold checkmark
- For **cash** bookings: copy reads "Booking Received — your booking is pending approval; you'll
  be notified once confirmed" (status is `pending`/`pending_approval`, not confirmed yet)
- For **card** bookings: standard confirmed copy (card path is a placeholder that behaves as
  auto-approved — see §9 Business Logic)
- Button to navigate to Bookings tab

#### Bookings Tab (inside ClientShell)
- Three-section list: Upcoming, Past, Cancelled
- Each booking card: route, date/time, vehicle, status badge, price
- "Modify" button: only visible within modification window (>24h before departure)
- "Cancel" button: only visible within cancellation window (>24h before departure)
- Pull-to-refresh

#### Favorites Tab
- Lists saved locations with type icons (home, work, airport, custom)
- "Add Location" button → modal sheet with label, address, type fields
- Swipe-to-delete or delete icon

#### Notifications Tab
- Notification list, newest first (last 50 loaded from server)
- Unread badge on ClientShell bottom nav icon
- Tap to mark read; bulk "mark all read" action
- Notification types: booking_received, status_update, cancelled, info

#### Profile Tab
- Displays avatar, name, email, phone
- Edit profile → `PUT /auth/me`
- Avatar upload → `POST /auth/me/avatar`
- **"CARTHAGE PRIVILÈGE" membership card** (added 2026-07-08, replaces the earlier buried Rewards
  row): dark-lacquer card showing tier chip, points hero number, gold progress bar to next tier,
  rides-remaining copy, member name — sourced from `GET /rewards/me`; hidden for guests
- Language toggle: English / Français (saved to server + local)
- Theme toggle: Light / Dark (saved to server + local)
- Logout: clears token + navigates to `/auth`

#### `vehicles_screen.dart`
- Full fleet catalog (browseable outside booking flow)
- Loads from `GET /cars` (available only)

#### `services_screen.dart`
- Premium add-on services display (currently static/informational)

#### `destinations_screen.dart`
- Entry point to Tunisia destination discovery
- Navigation to `/destination-guide`

#### `assistant_screen.dart`
- Chat UI with AVA AI assistant
- Time-aware greeting (morning/afternoon/evening)
- Speech-to-text microphone button
- Message bubbles (user right, AVA left)
- Typing indicator while waiting for response
- Calls `AssistantService` → backend AI endpoint

#### `edit_profile_screen.dart`
- Full name, email, phone fields
- Avatar image picker
- Saves via `PUT /auth/me`

---

## 6. Admin Dashboard

### AdminShell — Bottom Navigation
File: `DHC_transport/lib/features/admin/presentation/admin_shell.dart`

| Tab | Screen |
|---|---|
| 0 | Dashboard (overview + analytics) |
| 1 | Bookings (all bookings management) |
| 2 | Fleet (vehicle management) |
| 3 | Profile (admin account) |

---

### Admin Screen Breakdown

#### `admin_dashboard_screen.dart`
**Metric Cards (top row):**
- Total Bookings (all-time count)
- Total Clients (registered users count)
- Total Vehicles (fleet size)
- Pending Bookings (awaiting confirmation)

**Booking Status Breakdown:**
- Pending / Confirmed / Completed / Cancelled counts displayed as cards or list

**Pending Cash Approvals (new, 2026-07-08):**
- Gold-bordered section, count badge, horizontal scrollable cards (client, route, date, vehicle,
  price) for every booking with `payment_status: "pending_approval"`
- Tap → approve sheet → `PATCH /admin/bookings/{id}/approve-payment` → booking confirmed, client
  notified, card disappears from the list on reload

**Quick Actions:**
- Button grid → Bookings, Fleet, Promotions, Pricing, **Complaints** (new)

**Revenue Section:**
- Total revenue from completed bookings
- Revenue breakdown by vehicle category

**7-Day Booking Trend:**
- Daily booking counts for the past 7 days

**Open Complaints tile (new):**
- Live count from `GET /admin/overview` (`open_complaints`)

**Most Booked Vehicle:**
- Vehicle class with highest booking count

Data fetched from: `GET /api/v1/analytics/dashboard` + `GET /api/v1/admin/overview`

---

#### `admin_bookings_screen.dart`
- Lists ALL bookings (not filtered by user) from `GET /admin/bookings`
- Filter chips: All / **Pending Approval** (client-side filter on `payment_status ==
  "pending_approval"`) / Pending / Confirmed / On Route / Completed / Cancelled
- Each booking card: passenger name, route, vehicle, date, status badge, price
- Actions per booking:
  - **View details** → `admin_booking_details_screen.dart`
  - **Edit** → `booking_edit_sheet.dart` modal
  - **Change status** → `PATCH /bookings/{id}/status` (pending/confirmed/on_route/completed/cancelled)
  - **Delete** → `DELETE /bookings/{id}`
- Pull-to-refresh

#### `admin_booking_details_screen.dart`
- Full booking record: passenger info, contact, pickup, destination, vehicle, pricing breakdown
- Status history
- Quick status change buttons

#### `booking_edit_sheet.dart` (modal bottom sheet)
- Edit: passenger name, phone, pickup location, destination, departure date/time, return date/time, passenger count, luggage count
- Saves via `PUT /bookings/{id}`

---

#### `admin_cars_screen.dart`
- Fetches from `GET /cars/all` (includes unavailable)
- Vehicle list with category badge, seats, price (real 8-vehicle fleet: Economy, Comfort Sedan,
  Minivan, Large Van, Minibus, Mercedes E/S/V Class; legacy `Standard|VIP|Luxury|Van` categories
  are still accepted server-side for backward compatibility)
- Toggle availability: `PATCH /cars/{id}/availability?available=true|false`
- Edit vehicle: `PUT /cars/{id}` (inline edit or modal)
- Delete: `DELETE /cars/{id}`
- Add new vehicle: `POST /cars` with fields: name, model, category, seats, luggage, base_price,
  image_url, availability, `pricing` object, `features`

---

#### `admin_pricing_screen.dart` — **per-vehicle rate editor (rewritten 2026-07-07, replaces the old surcharge-rules form)**
- Lists every fleet vehicle as a card with its live rates (initial fee, return fee, per-km,
  per-hour, per-waypoint); Economy shows a **"VERIFY RATES"** badge because its source data
  (`pricing_verified: false`) was extracted from a truncated PDF and needs human correction
- Tapping a card opens an editor sheet with one number input per pricing parameter; Save calls
  `PUT /cars/{id}` with the full `pricing` object (and syncs `base_price` to the initial fee) —
  this write also appends a `pricing_history` record, which feeds AVA's pricing-impact analytics
- The old dedicated surcharge-rules FORM (night/weekend/last-minute/seasonal toggles) was removed
  from this screen per an explicit product decision, but the underlying rules and the
  `PUT /pricing/rules` endpoint still exist and are still applied on top of the real base price
  at booking time (see §15)

---

#### `admin_complaints_screen.dart` (new, 2026-07-07)
- Pushed from the dashboard quick-action → `GET /complaints/` (admin-only), newest first
- Filter chips: All / Open / In review / Resolved
- Status badges per complaint; tapping opens a detail sheet with user/booking/message/timestamp
  and a status selector → `PATCH /complaints/{id}/status` (statuses: `open`, `in_review`,
  `resolved`; invalid status → 400; non-admin → 403)
- Complaint documents key on `_id` (not `id`) in the API response — the screen reads `_id` with
  an `id` fallback

---

#### `admin_promotions_screen.dart`
Fetches from `GET /promotions`, full CRUD.

**Promotion Fields:**
| Field | Description |
|---|---|
| `code` | Unique promo code string (uppercase, e.g. WELCOME10) |
| `discount_type` | `"percentage"` or `"fixed"` |
| `value` | Discount value (% or fixed amount in TND) |
| `expiry_date` | ISO datetime or null (no expiry) |
| `usage_limit` | Max redemptions (0 = unlimited) |
| `usage_count` | Current redemptions (auto-incremented) |
| `active` | Toggle on/off |

**Actions:**
- Create new promotion
- Toggle active/inactive: `PATCH /promotions/{id}/toggle`
- Edit: `PUT /promotions/{id}`
- Delete: `DELETE /promotions/{id}`

---

#### `admin_suppliers_screen.dart`
> **Reachable as of 2026-07-27.** The 4-tab bottom nav is unchanged
> (Dashboard/Bookings/Fleet/Profile), but the dashboard "Quick actions" card now has a
> **"Suppliers"** entry: `admin_dashboard_screen.dart` exposes an `onOpenSuppliers` callback that
> `admin_shell.dart` binds to `_pushSuppliers()` → `Navigator.push(AdminSuppliersScreen())`.
> (Previously dead code — no push route referenced `AdminSuppliersScreen` before this.)

Fetches from `GET /suppliers`.

**Supplier Fields:**
| Field | Description |
|---|---|
| `name` | Supplier company name |
| `phone` | Contact phone |
| `email` | Contact email |
| `handle` | Short identifier/username |
| `status` | `"active"` / `"inactive"` / `"suspended"` |

**Actions:**
- Create supplier: `POST /suppliers`
- Edit: `PUT /suppliers/{id}`
- Change status: `PATCH /suppliers/{id}/status`
- Delete: `DELETE /suppliers/{id}`

---

#### `admin_profile_screen.dart`
- Shows admin full name, email, role
- Permissions info block
- Logout button

---

#### `recommendation_management_screen.dart`
Admin interface to manage Destination Guide content.
> **Reachable as of 2026-07-27.** The dashboard "Quick actions" card now has a **"Destinations"**
> entry: `admin_dashboard_screen.dart` exposes an `onOpenRecommendations` callback that
> `admin_shell.dart` binds to `_pushRecommendations()` →
> `Navigator.pushNamed(AppRoutes.recommendationManagement)` (the already-registered
> `/admin/recommendations` route). (Previously the route existed but nothing navigated to it.)
- Fetches from `GET /destinations/recommendations/`
- Filter by category: restaurant, hotel, cafe, activity
- Create new recommendation: `POST /destinations/recommendations/`
- Toggle visibility and featured status
- Edit recommendation details

---

## 7. Backend API — Complete Endpoint Reference

Base path: `/api/v1/`

### AUTH — `/auth`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/login` | Public | Email + password → JWT token + role + profile |
| POST | `/auth/signup` | Public | Register new client account |
| GET | `/auth/me` | Client | Get current user profile |
| PUT | `/auth/me` | Client | Update profile (name, email, phone, language, theme, avatar_url) |
| POST | `/auth/me/avatar` | Client | Upload avatar image (JPG/PNG/WebP multipart) |
| POST | `/auth/forgot-password` | Public | Request password reset email |
| POST | `/auth/reset-password` | Public | Consume reset token, set new password |

---

### BOOKINGS — `/bookings`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/bookings/price-estimate` | Client | Real distance-based quote: with `vehicle_id` → one quote; without → batch quote for the whole fleet from a single Google Directions call |
| GET | `/bookings/` | Client | List own bookings (admin sees all); query `?booking_status=` |
| GET | `/bookings/history` | Client | Bookings grouped: upcoming, past, cancelled |
| GET | `/bookings/{id}` | Client | Single booking detail (ownership enforced; admin exempt) |
| POST | `/bookings/` | Client | Create booking (`payment_method` defaults to `"cash"`); enforces minimum advance notice; sets `payment_status`; tracks promo usage; emits notification (cash → notifies all admins) |
| PUT | `/bookings/{id}` | Client | Modify booking; enforces modification window (admin exempt); emits notification on status change |
| PATCH | `/bookings/{id}/cancel` | Client | Cancel booking; enforces cancellation window; emits cancellation notification |
| PATCH | `/bookings/{id}/status` | Admin | Set status directly: pending / confirmed / on_route / completed / cancelled |
| DELETE | `/bookings/{id}` | Admin | Hard delete booking record |

---

### CARS — `/cars`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/cars/` | Public | List available cars (availability=true), sorted by base_price |
| GET | `/cars/all` | Admin | All cars including unavailable |
| POST | `/cars/` | Admin | Create car: name, model, category, seats, luggage, base_price, image_url, `pricing` object |
| PUT | `/cars/{id}` | Admin | Update car fields; writes a `pricing_history` record whenever `pricing` changes |
| PATCH | `/cars/{id}/availability` | Admin | Toggle availability (`?available=true|false`) |
| DELETE | `/cars/{id}` | Admin | Remove car |

Real fleet categories (8, seeded from `app/db/fleet_data.py`): `Economy`, `Comfort Sedan`,
`Minivan`, `Large Van`, `Minibus`, `Mercedes E Class`, `Mercedes S Class`, `Mercedes V Class`.
Legacy categories `Standard`/`VIP`/`Luxury`/`Van` are still accepted server-side for backward
compatibility but are no longer part of the seeded fleet.

---

### PRICING — `/pricing`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/pricing/config` | Public | Get full pricing rules (surcharges, limits) |
| POST | `/pricing/promo/validate` | Public | Validate promo code: body `{code, subtotal}` → returns discount amount |
| PUT | `/pricing/rules` | Admin | Update pricing configuration |

---

### PROMOTIONS — `/promotions`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/promotions/` | Admin | List all promotions |
| POST | `/promotions/` | Admin | Create promotion (validates code uniqueness) |
| PUT | `/promotions/{id}` | Admin | Update promotion fields |
| PATCH | `/promotions/{id}/toggle` | Admin | Toggle `active` status |
| DELETE | `/promotions/{id}` | Admin | Delete promotion |

---

### FAVORITES — `/favorites`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/favorites/` | Client | List user's saved locations |
| POST | `/favorites/` | Client | Add favorite: label, address, type (home/work/airport/custom) |
| DELETE | `/favorites/{id}` | Client | Remove favorite (ownership enforced) |

---

### DESTINATIONS — `/destinations`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/destinations/` | Public | List destination records |
| POST | `/destinations/` | Public | Create destination |
| GET | `/destinations/recommendations/` | Public | List recommendations; query `?city=&category=`; returns 6 defaults if empty |
| POST | `/destinations/recommendations/` | Public | Create recommendation |

---

### ADMIN — `/admin`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/admin/overview` | Admin | Dashboard stats: totals, status breakdown, `open_complaints`, `total_complaints` |
| GET | `/admin/bookings` | Admin | All bookings unfiltered by user; query `?booking_status=` |
| PATCH | `/admin/bookings/{id}/approve-payment` | Admin | Approve a pending cash (or card-placeholder) booking: sets `payment_status=approved`, `status=confirmed`, notifies the client |
| GET | `/admin/users` | Admin | All client users (passwords excluded) |
| POST | `/admin/seed` | Admin | Populate DB with default seed data (cars, pricing, promos, destinations) |

---

### COMPLAINTS — `/complaints`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/complaints/` | Client | Submit a complaint (`booking_id` optional, `message`); status starts `"open"`. Also invoked internally by AVA's `submit_claim` tool. |
| GET | `/complaints/` | Admin | List all complaints, newest first |
| PATCH | `/complaints/{id}/status` | Admin | Set status: `open` / `in_review` / `resolved` (400 on invalid value) |

---

### NOTIFICATIONS — `/notifications`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/notifications/` | Client | Last 50 notifications for user, newest first |
| PATCH | `/notifications/{id}/read` | Client | Mark single notification read |
| PATCH | `/notifications/read-all` | Client | Mark all user notifications read |
| DELETE | `/notifications/{id}` | Client | Delete notification |
| POST | `/notifications/` | Admin | Push notification to specific user (user_id, title, message, notif_type) |

---

### SUPPLIERS — `/suppliers`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/suppliers/` | Admin | List all suppliers |
| POST | `/suppliers/` | Admin | Create supplier |
| PUT | `/suppliers/{id}` | Admin | Update supplier fields |
| PATCH | `/suppliers/{id}/status` | Admin | Set status: active / inactive |
| DELETE | `/suppliers/{id}` | Admin | Remove supplier |

---

### REWARDS — `/rewards`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/rewards/me` | Client | User's loyalty profile: points, tier, next tier threshold, available promo codes |
| GET | `/rewards/available-promos` | Client | List active promo codes |

---

### ANALYTICS — `/analytics`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/analytics/dashboard` | Admin | Full analytics: booking stats, revenue by category, popular destinations, 7-day trend, most booked vehicle |

---

### CONFIG — `/config`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/config/cities` | Public | List Tunisian cities (21 defaults if empty) |
| POST | `/config/cities` | Public | Add city by name |

---

## 8. Database — Collections & Schemas

### `users`
```json
{
  "_id": "ObjectId",
  "full_name": "string",
  "email": "string (unique)",
  "phone": "string",
  "hashed_password": "string",
  "avatar_url": "string | null",
  "role": "client | admin",
  "preferred_language": "en | fr",
  "theme_mode": "light | dark | system",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### `bookings`
```json
{
  "_id": "string (uuid)",
  "user_id": "string (ref: users)",
  "driver_id": "string | null",
  "passenger_name": "string",
  "passenger_phone": "string",
  "pickup_location": "string",
  "destination_name": "string",
  "destination_city": "string",
  "vehicle_type": "string",
  "vehicle_class": "Economy | Comfort Sedan | Minivan | Large Van | Minibus | Mercedes E/S/V Class (+legacy Standard|VIP|Luxury|Van)",
  "status": "pending | confirmed | on_route | completed | cancelled",
  "payment_method": "cash | card",
  "payment_status": "pending_approval | approved",
  "trip_type": "one-way | round-trip",
  "departure_date": "YYYY-MM-DD",
  "departure_time": "HH:MM",
  "return_date": "YYYY-MM-DD | null",
  "return_time": "HH:MM | null",
  "passenger_count": "int",
  "luggage_count": "int",
  "promo_code": "string | null",
  "dynamic_surcharge": "float",
  "discount_amount": "float",
  "total_price": "float",
  "estimated_earnings": "float",
  "contact_email": "string",
  "contact_phone": "string",
  "guest_email": "string | null",
  "guest_phone": "string | null",
  "is_guest": "boolean",
  "eta_minutes": "int | null",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### `cars`
```json
{
  "_id": "string",
  "name": "string",
  "model": "string",
  "category": "Economy | Comfort Sedan | Minivan | Large Van | Minibus | Mercedes E/S/V Class",
  "seats": "int",
  "luggage": "int",
  "base_price": "float (synced to pricing.initial_fee)",
  "availability": "boolean",
  "image_url": "string",
  "pricing": {
    "initial_fee": "float (EUR)",
    "initial_fee_return": "float",
    "per_km": "float",
    "per_km_return": "float",
    "per_hour": "float",
    "per_extra_hour": "float",
    "per_waypoint": "float",
    "per_waypoint_duration_per_min": "float",
    "currency": "EUR",
    "pricing_verified": "boolean (false on Economy — source data truncated)"
  },
  "features": ["string"],
  "created_at": "datetime",
  "updated_at": "datetime"
}
```
Single source of truth for the seeded fleet: `backend/app/db/fleet_data.py` (used by both
`seed.py` and the `cars.py` bootstrap).

### `pricing_history`
Written by `PUT /cars/{id}` on every pricing change; feeds AVA's pricing-impact analytics.
```json
{
  "_id": "string",
  "car_id": "string (ref: cars)",
  "old_pricing": { "...": "previous pricing object" },
  "new_pricing": { "...": "updated pricing object" },
  "changed_at": "datetime"
}
```

### `complaints`
```json
{
  "_id": "string (claim-<uuid hex>)",
  "user_id": "string (ref: users)",
  "booking_id": "string | null",
  "message": "string",
  "status": "open | in_review | resolved",
  "created_at": "datetime",
  "updated_at": "datetime | absent until first status change"
}
```

### `pricing_rules`
Single document, `_id: "active"`.
```json
{
  "_id": "active",
  "minimum_booking_hours": "int",
  "modification_limit_hours": "int",
  "cancellation_limit_hours": "int",
  "night_pricing": {
    "enabled": "boolean",
    "start_time": "HH:MM",
    "end_time": "HH:MM",
    "percentage": "float"
  },
  "last_minute_pricing": {
    "enabled": "boolean",
    "within_hours": "int",
    "percentage": "float"
  },
  "weekend_pricing": {
    "enabled": "boolean",
    "percentage": "float"
  },
  "seasonal_pricing": {
    "enabled": "boolean",
    "percentage": "float",
    "label": "string"
  },
  "updated_at": "datetime"
}
```

### `promotions`
```json
{
  "_id": "string",
  "code": "string (unique, uppercase)",
  "discount_type": "percentage | fixed",
  "value": "float",
  "expiry_date": "ISO datetime | null",
  "usage_limit": "int (0 = unlimited)",
  "usage_count": "int",
  "active": "boolean",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### `favorites`
```json
{
  "_id": "string",
  "user_id": "string (ref: users)",
  "label": "string",
  "address": "string",
  "type": "home | work | airport | custom",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### `notifications`
```json
{
  "_id": "string",
  "user_id": "string (ref: users)",
  "title": "string",
  "message": "string",
  "type": "booking_received | status_update | cancelled | info",
  "booking_id": "string | null",
  "read": "boolean",
  "created_at": "datetime"
}
```

### `suppliers`
```json
{
  "_id": "string",
  "name": "string",
  "phone": "string",
  "email": "string",
  "handle": "string",
  "status": "active | inactive | suspended",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### `recommendations`
```json
{
  "_id": "string",
  "category": "restaurant | hotel | cafe | activity",
  "name": "string",
  "city": "string",
  "region": "string",
  "image_url": "string",
  "rating": "float",
  "price_range": "$ | $$ | $$$ | $$$$ | Free",
  "tags": ["string"],
  "description": "string",
  "notes": "string",
  "phone": "string",
  "opening_hours": "string",
  "primary_label": "string",
  "primary_value": "string",
  "secondary_label": "string",
  "secondary_value": "string",
  "tertiary_label": "string",
  "tertiary_value": "string",
  "featured": "boolean",
  "visible": "boolean",
  "created_at": "datetime"
}
```

### `destinations`
```json
{
  "_id": "string",
  "name": "string",
  "city": "string",
  "region": "string",
  "description": "string",
  "visible": "boolean",
  "created_at": "datetime"
}
```

### `password_resets`
```json
{
  "_id": "ObjectId",
  "token": "string (unique, UUID)",
  "user_id": "string",
  "expires_at": "datetime (created_at + 1 hour)"
}
```

### `cities`
```json
{
  "_id": "string",
  "name": "string"
}
```

### `chat_sessions`
```json
{
  "_id": "string",
  "user_id": "string",
  "messages": [
    {
      "role": "user | assistant",
      "content": "string",
      "timestamp": "datetime"
    }
  ],
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

---

## 9. Business Logic & Rules

### Booking Time Constraints
All enforced server-side (admin is exempt from time window checks):

| Rule | Default | Config Field |
|---|---|---|
| Minimum advance booking | 3 hours | `minimum_booking_hours` |
| Modification deadline | 24 hours before departure | `modification_limit_hours` |
| Cancellation deadline | 24 hours before departure | `cancellation_limit_hours` |

### Booking Status State Machine
```
pending → confirmed → on_route → completed
    ↓          ↓          ↓
 cancelled  cancelled  cancelled
```
Admin can set any status directly. Client can only cancel.

### Promo Code Validation (server-side)
1. Code must exist and `active: true`
2. `expiry_date` must be null or in the future
3. `usage_count` must be less than `usage_limit` (or `usage_limit = 0` = unlimited)
4. On booking creation: `usage_count` is incremented automatically

### Avatar Upload Constraints
- Accepted MIME types: `image/jpeg`, `image/png`, `image/webp`
- Stored at a URL path, `avatar_url` saved to user document

### Payment & Approval Flow (added 2026-07-08)
1. Client picks `payment_method` on `PaymentMethodScreen`: `cash` (real, selectable) or `card`
   (placeholder — UI redirects to cash; **no card payment ever actually processes**)
2. `POST /bookings/` sets `payment_status`:
   - `cash` → `pending_approval`; a notification is pushed to **every** admin user
     ("Cash booking awaiting approval")
   - `card` → `approved` (placeholder auto-approve; still not a real charge)
3. Booking `status` stays `pending` until an admin acts. Cash success screen tells the client
   the booking is pending approval, not confirmed.
4. Admin approves via `PATCH /admin/bookings/{id}/approve-payment` → `payment_status=approved`,
   `status=confirmed`, client is notified ("Booking confirmed").
5. There is no real payment gateway anywhere in the stack — this flow only governs whether a
   booking auto-confirms or waits on a human, not whether money moves.

---

## 10. AI Assistant (AVA)

### Architecture
AVA is a real **LangChain + LangGraph** agent running on the backend (`backend/app/ai/`), not a
scripted or local-only demo. `POST /assistant/chat` streams the response over SSE; the Flutter
`AssistantScreen` / `AdminAssistantScreen` consume it via `assistant_api_service.dart`.

Pipeline: `supervisor.py` receives the message → intent classification (Gemini call) **or** a
deterministic "Guard 0" fast path for known phrase patterns (currently used for admin analytics
requests, to skip the classify call) → `role_gate` (client JWT cannot reach admin tools) →
dispatch to the matching sub-agent → tool execution (state-changing tools go through a
confirmation gate) → `safety` node → session write (`chat_sessions`).

### Sub-agents (`backend/app/ai/agents/`)
| Agent | File | Scope |
|---|---|---|
| Booking | `booking_agent.py` | Trip history, real-fleet vehicle recommendation, create/modify/cancel a booking (4-node internal router) |
| Support (RAG) | `support_agent.py` | Company policy / FAQ Q&A over the vector knowledge base |
| Loyalty | `loyalty_agent.py` | Points, tier, promo codes (+ deterministic template fallback if Gemini is unavailable) |
| Feedback | `feedback_agent.py` | Structures a complaint and calls `submit_claim` → `POST /complaints/` |
| Operations (admin) | `operations_agent.py` | Fleet, pricing, suppliers, promotions — state-changing, gated behind confirmation + audit log |
| Insights (admin) | `insights_agent.py` | Read-only analytics, user list, booking list, and the business-analytics fast path (below) |
| Shared | `shared.py` | `run_with_confirmation` (propose → yes/no → execute), audit-log wrapper |

### Admin Business Analytics (added 2026-07-08)
A full BI pipeline, not a stub: admin message → supervisor Guard 0 (deterministic phrase
detection in `analysis_triggers.py`, admin-only, skips the Gemini classify call) → insights
agent fast path calls `run_business_analysis` directly → `analytics_service.py` (6 real MongoDB
aggregation methods: revenue by month, revenue by vehicle category, booking volume trend,
seasonal analysis, pricing-impact analysis via the `pricing_history` collection, KPI summary) →
deterministic chart specs + KPIs + insights, plus **one** dedicated Gemini call for the narrative
(falls back to a deterministic summary on quota failure — never crashes the turn) → the payload
rides `AIMessage.additional_kwargs["analytics"]` through supervisor state → the SSE stream emits
an `"analytics"` event before `"done"` → Flutter's `AssistantController` stashes it on the
message and `AnalyticsCard` (`fl_chart`) renders KPI tiles, a narrative, and line/area/bar/pie
charts instead of a plain text bubble. Verified live: "Give me a full business review" and
"How did our pricing changes affect bookings?" both return narratives whose numbers match the
database exactly (e.g. accurate revenue-to-the-euro, correct booking counts).

### RAG / Knowledge Base
- 5 real documents in `ai/knowledge/`: `faq.txt`, `pricing_policy.txt`,
  `terms_and_conditions.txt`, `vehicles.txt`, `destinations.txt`
- ChromaDB vector store at `ai/vectorstore/chroma.sqlite3` (rebuilt 2026-07-08); a
  `source_manifest.json` (per-file SHA-256) drives a staleness guard that warns on startup if a
  knowledge file changed since the index was last built
- Relevance floor: 0.25 confidence — below it, `search_knowledge_base` returns no context rather
  than hallucinating from irrelevant chunks
- **Low-confidence query expansion** (added 2026-07-07): if the best first-pass score is below
  0.50 and the query mentions "airport", a second retrieval runs with KB-vocabulary phrasing;
  results are merged/deduped. Root cause fixed: the word "assistance" never appears in the KB, so
  "airport assistance" queries previously missed the relevant waiting-time/meet-driver chunks.

### Safety / Confirmation / Audit
- State-changing tools (create/modify/cancel booking, edit pricing, manage suppliers/promotions)
  go through `run_with_confirmation`: AVA proposes the action, the user must reply yes/no, only
  then does the tool execute
- Every admin tool call is wrapped and written to the `audit_log` collection
- User identity (`user_id`) is bound server-side and never exposed to the LLM — the model cannot
  be prompted into acting as a different user
- **Friendly-error guarantee, 3 layers**: (1) `model_router.invoke_with_fallback` collapses any
  Gemini failure (429/RESOURCE_EXHAUSTED/etc.) to a fixed friendly message; (2) `_run()` in
  `assistant.py` catches any sub-agent exception directly; (3) the entire supervisor-graph
  construction is wrapped, so even a graph-build failure yields the friendly SSE error event
  instead of a raw 500. The raw provider error text never reaches the Flutter chat bubble.

### Model Routing
Flat, Gemini-only (`model_router.py`, gated on `GOOGLE_API_KEY`). The earlier local/Ollama
routing tier has been fully removed. Free-tier quota is 20 requests/day; on exhaustion, AVA shows
the friendly "temporarily unavailable" message (loyalty/vehicle-recommendation tools still return
correct deterministic answers via template fallbacks that don't need the LLM).

### Voice Input
- Flutter `speech_to_text: ^7.0.0` package captures voice; `SpeechToText()` instantiated in
  `assistant_screen.dart`. The package and instance are real, but the full
  mic-permission → transcript → send wiring has not been traced end-to-end on a physical device.
- Transcribed text sent as message to AVA; response displayed as text/cards in chat UI

### Chat Session Persistence
- `chat_sessions` collection stores full conversation history per user
- Sessions retrievable for continuity across app restarts

### Evaluation
- `backend/app/ai/evaluation/`: 28 test cases (`test_cases.py`) + `run_eval.py`
- Latest baseline: `results_2026-06-30_10-29-26.md` — 24/28 as-run (a few cases ran on a local
  model substitute to conserve the 20/day Gemini quota); not re-run against production Gemini
  since the 2026-07-07→07-09 agent changes (recommend_vehicle on the real fleet, RAG query
  expansion, the analytics fast path)

---

## 11. Loyalty & Rewards System

> UI note: since 2026-07-08 this data is surfaced via a "CARTHAGE PRIVILÈGE" membership card
> embedded directly in the Profile tab (not a separate Rewards screen anymore).

### Points Calculation
- **Earn rate:** 10 points per completed trip
- **Formula:** `points = completed_trips_count × 10`
- Points are computed on the fly (not stored) from `bookings` where `status = "completed"`

### Tier Structure
| Tier | Points Required |
|---|---|
| Bronze | 0 – 49 |
| Silver | 50 – 149 |
| Gold | 150 – 299 |
| Black | 300+ |

### `GET /rewards/me` Response
```json
{
  "points": 120,
  "completed_trips": 12,
  "tier": "Silver",
  "next_tier": "Gold",
  "next_tier_threshold": 150,
  "promo_codes": [...]
}
```

### Promo Code Access
- `GET /rewards/available-promos` returns all `active: true` promotions
- Currently not filtered by tier (future feature: tier-gated promos)

---

## 12. Destination Guide & Recommendations

### Structure
- **Destinations** (`/destinations`) — City/region-level entries (e.g. "Carthage", "Sidi Bou Saïd")
- **Recommendations** (`/destinations/recommendations/`) — Specific places: restaurants, hotels, cafes, activities

### Default Seed
If the recommendations collection is empty, the API returns 6 hardcoded default entries covering Tunis-area highlights.

### Recommendation Fields Used in UI
- `name`, `city`, `category`, `rating`, `price_range`, `image_url`
- `description`, `tags`, `opening_hours`, `phone`
- `primary_label` / `primary_value` — flexible key-value display pair
- `secondary_label` / `secondary_value` — second key-value pair
- `tertiary_label` / `tertiary_value` — third key-value pair
- `featured` — highlights card in UI
- `visible` — hides from client if false (admin can unpublish)

### Admin Management
- `RecommendationManagementScreen` allows CRUD on recommendations
- Filter by category to manage restaurant vs. hotel vs. activity separately

---

## 13. Notifications System

### Trigger Events (auto-pushed by backend)
| Event | Notification Type | Who Receives |
|---|---|---|
| Booking created | `booking_received` | Booking user |
| Cash booking created (awaiting approval) | — | **All admin users** ("Cash booking awaiting approval") |
| Cash payment approved | `status_update` | Booking user ("Booking confirmed") |
| Status changed (confirmed, on_route, completed) | `status_update` | Booking user |
| Booking cancelled | `cancelled` | Booking user |

Note: an earlier bug caused duplicate notifications on status changes (one from the shared
status-message helper, one generic push from the endpoint); this was fixed by centralizing all
status copy in one place and removing the redundant endpoint-level pushes.

### Admin Manual Push
Admin can push arbitrary `info` notifications to any user via `POST /notifications/` with `user_id`.

### Client Access
- Last 50 notifications, sorted newest first
- Unread badge count computed from `read: false` records
- `PATCH /notifications/read-all` for bulk mark-read

---

## 14. Supplier Management

Suppliers represent third-party transport companies or sub-contractors used by Carthage Transfer.

### Status Values
| Status | Meaning |
|---|---|
| `active` | Currently operating, can be assigned trips |
| `inactive` | Temporarily not available |
| `suspended` | Removed from operations (compliance, contract issues) |

### Integration Gap (Future Work)
- Suppliers are currently managed as a standalone entity
- No direct link between a `supplier` record and a `booking` or `car` record yet
- Future: assign a supplier to a booking/driver, track earnings per supplier

### UI Reachability
The backend is fully implemented and `admin_suppliers_screen.dart` exists, but **the screen is
not reachable from the running app** — it is not one of the 4 `AdminShell` tabs and no push
route in `lib/` references it (verified 2026-07-14). Functionally dead code until wired in.

---

## 15. Dynamic Pricing Engine

Rewritten 2026-07-07 to replace the earlier flat-`base_price` model with a real distance-based
engine. Two layers, applied in order: (1) a per-vehicle rate card computes a real base price from
actual route distance, (2) the existing surcharge rules layer additive percentages on top.

### Layer 1 — Real per-vehicle rate cards
Each of the 8 fleet vehicles carries a `pricing` object (see `cars` schema, §8) sourced from the
live site's own booking-system data (`backend/app/db/fleet_data.py`, the single source of truth
for both the seed script and the `cars.py` bootstrap).

- `app/services/pricing_calculator.py`:
  - `get_route_metrics(origin, destination)` — real distance/duration via the Google Directions
    API (`settings.maps_api_key`); falls back to `haversine × 1.3` if Directions is unavailable
  - `calculate_price(vehicle, distance_km, trip_type)` — **formula invariant:** a distance
    transfer total = `initial_fee + distance_km × per_km` (+ waypoint components if any).
    `per_hour` is **not** added to distance transfers — verified against the live site's own
    quote for a real route, which only reconciles without the hourly term (adding it would
    double-bill). Return trips use `initial_fee_return + 2 × distance_km × per_km`.
- `POST /bookings/price-estimate` (auth required): with `vehicle_id` → single quote; without →
  batch quotes for the entire fleet computed from **one** Directions API call.
- Live-verified example: TUN airport → Hammamet = 73.53 km (real Google route via the A1), Comfort
  Sedan one-way = 12.98 + 73.53 × 0.413 = **43.35 EUR** exactly.
- ⚠️ Economy vehicle rates are seeded from a truncated source PDF and flagged
  `pricing_verified: false`; the admin Pricing screen shows a "VERIFY RATES" badge until a human
  corrects the exact decimals from the WordPress admin.

### Layer 2 — Surcharge rules (unchanged mechanism, now applied on top of the real base)
Stored in the single `pricing_rules` document (id: `"active"`), fetched via `GET /pricing/config`.

| Type | Trigger | Config |
|---|---|---|
| **Night** | Departure time falls between `start_time` and `end_time` | `night_pricing.enabled`, `start_time`, `end_time`, `percentage` |
| **Last-Minute** | Booking created within `within_hours` of departure | `last_minute_pricing.enabled`, `within_hours`, `percentage` |
| **Weekend** | Departure falls on Saturday or Sunday | `weekend_pricing.enabled`, `percentage` |
| **Seasonal** | Admin manually toggles (e.g. summer peak, Ramadan) | `seasonal_pricing.enabled`, `percentage`, `label` |

The admin Pricing screen no longer has a dedicated form for these rules (removed 2026-07-07 in
favor of the per-vehicle rate editor), but `PUT /pricing/rules` still exists and the rules still
apply at booking/quote time.

### End-to-end calculation
1. `POST /bookings/price-estimate` returns the real distance-based base (EUR) for the chosen vehicle
2. Client (`PricingService.estimateFromBase`) layers night/weekend/last-minute/seasonal surcharges on top
3. Promo code discount applied if present
4. Result = `total_price` stored on booking, currency = `EUR`

### Fallback path
If pickup/destination coordinates are missing or `price-estimate` fails, the fleet screen falls
back to a local rules-based estimate (labeled "ESTIMATED" instead of "ALL-INCLUSIVE") derived
from the vehicle's EUR `base_price` — this fallback is also EUR, not TND (a 2026-07-09 fix: an
earlier client-side `_id`-vs-`id` join-key bug silently discarded every real quote and fell back
to a truncated, mislabeled "TND" estimate; both the join bug and the currency mislabeling are fixed).

---

## 16. Promotions System

### Promo Validation Flow
1. User enters code at checkout
2. Flutter calls `POST /pricing/promo/validate` with `{code, subtotal}`
3. Backend returns `{valid, discount_amount, message}`
4. Flutter shows discount in price summary
5. On booking creation, `promo_code` stored, `usage_count++`

### Discount Types
| Type | Behavior |
|---|---|
| `percentage` | Discount = `subtotal × (value / 100)` |
| `fixed` | Discount = `value` TND (floored at 0) |

### Failure Cases (returned in `message`)
- Code not found
- Code inactive
- Code expired
- Usage limit reached

---

## 17. Theming, Localization & UX

### Color Palette
| Token | Hex | Usage |
|---|---|---|
| Gold accent | `#C8A96B` | Primary CTAs, active nav item, badges |
| Dark surface | `#1B1B1B` | App background (dark mode) |
| Card surface | `#2A2A2A` | Card backgrounds (dark mode) |
| Light text | `#FFFFFF` / `#F5F5F5` | Primary text on dark |

### Typography
- **Font family:** Montserrat (Google Fonts)
- Weights used: 400 (regular), 600 (semibold), 700 (bold)

### Localization
- Supported languages: **English** (`en`) and **French** (`fr`)
- Language preference stored in `users.preferred_language` on server
- Also persisted locally via `SharedPreferences`
- Language toggle available in Profile tab (instant switch, no restart)
- `LanguageService` manages current locale throughout the app

### Theming
- Light and Dark modes fully supported
- User preference stored in `users.theme_mode` (`light` / `dark` / `system`)
- `ThemeService` manages current theme with `ValueNotifier`
- Toggle in Profile tab

### Bottom Navigation (Client — FINAL DESIGN, DO NOT CHANGE)
The `ClientShell` uses a custom **glass-pill + gold-expansion** bottom navigation bar. This design is considered final. Do not propose or implement redesigns to this component.

---

## 18. Infrastructure & Deployment

### Local Development
```bash
# Backend
cd backend
uvicorn app.main:app --reload --port 8000

# Flutter
cd DHC_transport
flutter run
```

### Docker Compose
`docker-compose.yml` at project root orchestrates:
- `api`: FastAPI app container
- `mongodb`: MongoDB 7 container

### Environment Variables (Backend)
Loaded via `pydantic-settings` from `.env`:
| Variable | Purpose |
|---|---|
| `MONGODB_URL` | MongoDB connection string |
| `DATABASE_NAME` | MongoDB database name |
| `SECRET_KEY` | JWT signing key |
| `ALGORITHM` | JWT algorithm (default: HS256) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | JWT expiry |
| `SMTP_HOST` | Email server host |
| `SMTP_PORT` | Email server port |
| `SMTP_USER` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |
| `FROM_EMAIL` | Sender email address |

### Flutter API Base URL
Configured in `DHC_transport/lib/core/services/transport_api_client.dart`. Change for production deployment.

---

## 19. Known Gaps & Future Work

This section was re-audited 2026-07-14 against the actual codebase (source reads + greps, not
description), and updated again 2026-07-27 after a live verification session (backend running,
real HTTP requests). Earlier versions of this doc listed several items as "not yet built" that are
now real (payment approval flow, complaints management, analytics charts) — those have been moved
out of this list; the two "built but unreachable" admin screens (Suppliers, Recommendations) were
wired into the dashboard on 2026-07-27 and are struck through below. What remains:

### Not Yet Built
- **Real-time tracking** — No live GPS tracking of driver location; `eta_minutes` is static
- **Real payment gateway** — No Stripe/PayPal/card processor anywhere in the stack. The
  cash-vs-card flow (§9) governs auto-confirm vs. admin-approval, not an actual charge; card is
  explicitly a "Coming Soon" placeholder that redirects to cash.
- **Push notifications (device)** — No `firebase_messaging` in `pubspec.yaml`; notifications are
  in-app list only, nothing is pushed to the device
- **Driver app** — No separate driver-side mobile interface; driver assignment is manual
- **Tier-gated promotions** — Rewards tiers exist but promo codes are not filtered by tier
- **Rating/review system** — No post-trip rating for drivers or vehicles
- **Supplier ↔ Booking link** — Suppliers exist as a module but aren't linked to bookings or cars

### Built but Unreachable in the App
- ~~**Admin Suppliers screen**~~ — **FIXED 2026-07-27**: now reachable via the "Suppliers"
  dashboard quick-action (`onOpenSuppliers` → `AdminShell._pushSuppliers` → `AdminSuppliersScreen`).
- ~~**Admin Recommendation Management screen**~~ — **FIXED 2026-07-27**: now reachable via the
  "Destinations" dashboard quick-action (`onOpenRecommendations` →
  `Navigator.pushNamed('/admin/recommendations')`).
- **Admin Users screen** — `GET /admin/users` is real; there is no Flutter screen for it at all
  (only a dashboard count + AVA's insights agent read it). *(Still unreachable — the only
  remaining item in this category.)*

### Partially Implemented
- **Password reset** — token issuance/validation is real (`password_resets` collection), but SMTP
  is unset by default (no email actually sent in the demo) and there's no in-app deep-link to
  finish the reset — the flow can't currently be completed end-to-end without manual DB access
- **Voice input** — `speech_to_text` package + instance are real; full mic→transcript→send wiring
  not traced end-to-end on a physical device
- **Economy vehicle pricing** — seeded from a truncated source PDF, flagged
  `pricing_verified: false`, needs a human to read exact values from the WordPress admin. The
  flag + "VERIFY RATES" badge both render correctly (verified live via `GET /cars/all`,
  2026-07-27) — this is a data-accuracy gap, not a code gap.
- **Demo data hygiene** — `POST /admin/seed` only clears 7 collections and **does not clear
  `complaints`, `chat_sessions`, `audit_log`, `favorites`, `pricing_history`**. As of 2026-07-27
  the DB holds ~63 stale complaints (58 from orphan test users `test-client-ava-001` /
  `test-stability-*`, mostly "driver was 30 minutes late" fixtures), ~124 audit rows, and ~15
  chat sessions from AI test runs — these survive a re-seed and show up in the admin Complaints
  screen / "open complaints" stat during a demo. Fix: extend the seed clear-list or clear those
  collections manually before demoing.
- **Gemini free-tier rate limit** — the free tier caps `gemini-2.5-flash` at **5 requests/minute**
  (`generate_content_free_tier_requests`); observed live 2026-07-27 when running 5 AVA scenarios
  back-to-back tripped a 429 on the multi-call booking agent. Each scenario passes in isolation and
  deterministic fallbacks fire on exhaustion. Last full eval run (2026-06-30) used a local-model
  substitute for some cases to conserve quota; not re-run against production Gemini since the
  pricing/analytics agent changes of 2026-07-07→07-09.

### Design Decisions to Revisit
- `GET /config/cities` is public (unauthenticated); adding cities is also public — should require admin auth
- `GET /destinations/` and `POST /destinations/` are both public — may need auth guard for creation
- Points are computed on-the-fly (no point ledger); no ability to award bonus points or adjust manually
- A live Google Maps API key is committed in `maps_config.dart` — should be rotated and moved to
  a gitignored config, not treated as a functional gap but a real security exposure
- Gemini free-tier quota (20 requests/day) directly limits how much of AVA (including the new
  business-analytics narrative, which costs 1 call per analysis) can be demoed without billing enabled

---

*Last updated: 2026-07-14 — Carthage Transfer / DHC Transport*
