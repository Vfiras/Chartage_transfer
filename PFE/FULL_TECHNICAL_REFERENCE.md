# Carthage Transfer — Full Technical Reference (PFE Jury Prep)

> **How to use this document.** Everything below was read from the actual source, not from memory or design docs. Every claim points to a real file so you can open it during study. Where the code contradicts its own comments/docs, that is called out explicitly with a ⚠ marker — the jury respects a student who knows the weak spots better than the examiner does.
>
> **App identity:** the project directory is `DHC_transport` and `pubspec.yaml` still calls it `dhc_transport` ("DHC Transport admin and driver Flutter app"), but the product is branded **Carthage Transfer** (`MaterialApp.title = 'Carthage Transfer'` in [main.dart](DHC_transport/lib/main.dart)). It is a **premium chauffeur / airport-transfer booking platform** with a client app, an admin app, and an AI concierge called **AVA**.
>
> **Three-tier architecture:** Flutter (mobile client + admin) → FastAPI (REST + SSE) → MongoDB, with a LangGraph multi-agent AI layer (AVA) inside the backend calling Google Gemini.

---

# PART 1 — FLUTTER FRONTEND

## 1. Why Flutter (and not Next.js / PWA / React Native / native)

### 1.1 The dependencies you actually ship

From [pubspec.yaml](DHC_transport/pubspec.yaml). Versions are the **resolved** versions from `pubspec.lock`.

| Package | Declared | Resolved | Role in THIS project | Where it's used |
|---|---|---|---|---|
| `flutter` (SDK) | sdk | — | The framework | everywhere |
| `flutter_localizations` (SDK) | sdk | — | Material/Cupertino widget translations (date & time pickers in FR) | [main.dart](DHC_transport/lib/main.dart) delegates |
| `cupertino_icons` | ^1.0.8 | 1.0.9 | iOS-style icon glyphs | icons |
| `google_fonts` | ^6.2.1 | 6.3.3 | Montserrat typeface loaded at runtime (no bundled font files) | [main.dart](DHC_transport/lib/main.dart) (`GoogleFonts.montserratTextTheme()`), 10 files |
| `http` | ^1.2.2 | 1.6.0 | REST + SSE transport; the whole API client | [transport_api_client.dart](DHC_transport/lib/core/services/transport_api_client.dart), places/directions/assistant services (4 files) |
| `image_picker` | ^1.0.7 | 1.0.7 | Pick avatar image from gallery/camera | [auth_service.dart](DHC_transport/lib/core/services/auth_service.dart) `uploadAvatar`, 3 files |
| `intl` | ^0.20.2 | 0.20.2 | `DateFormat` for dates/times; `Intl.defaultLocale` for FR/EN | [pricing_service.dart](DHC_transport/lib/core/services/pricing_service.dart), booking screens (7 files) |
| `shared_preferences` | ^2.3.0 | 2.5.5 | On-device key/value store: JWT token, user profile, theme, language, AVA thread id | auth/theme/language/assistant services (4 files) |
| `speech_to_text` | ^7.0.0 | 7.4.0 | Microphone → text for AVA voice input | [assistant_screen.dart](DHC_transport/lib/screens/assistant_screen.dart) `_InputBar` (1 file) |
| `google_maps_flutter` | ^2.9.0 | 2.17.1 | Native Google Map widget, markers, polylines, camera | [booking_search_screen.dart](DHC_transport/lib/screens/booking_search_screen.dart), 7 files |
| `fl_chart` | ^0.69.0 | 0.69.2 | Line/bar/pie/area charts in the AVA analytics card | [analytics_card.dart](DHC_transport/lib/screens/assistant/widgets/analytics_card.dart) (1 file) |
| `flutter_lints` (dev) | ^3.0.2 | 3.0.2 | Static-analysis lint rules | dev only |

**Dependency audit / honesty flags:**
- **Every declared dependency is actually imported and used** — confirmed by grepping `package:<name>` across `lib/`. There is no dead dependency in `pubspec.yaml`.
- `fl_chart` and `speech_to_text` are each used in exactly **one** file — they are feature-specific (analytics card; AVA voice). That's fine, just be ready to say so.
- There is **no state-management package** (no `provider`, `riverpod`, `flutter_bloc`, `get`). State is done with the framework's own primitives (see §2). This is a deliberate, defensible choice for an app this size and a key talking point.
- There is **no HTTP package beyond `http`** (no `dio`, no `retrofit`). The client is hand-written.
- Assets: `assets/images/`, `assets/images/fleet/`, `assets/images/partners/`, `assets/data/`.

### 1.2 The "why Flutter" argument for THIS project

Frame it around the concrete needs of Carthage Transfer:

1. **One codebase, two native apps, one brand.** The same `lib/` produces both the **client** app and the **admin** app (they are just two different initial routes — `AppRoutes.clientShell` vs `AppRoutes.adminShell`, chosen by role in [main.dart:52-56](DHC_transport/lib/main.dart#L52)). A native approach (Kotlin + Swift) would be 4 codebases (2 platforms × 2 apps).
2. **The map + booking flow is the core UX and must feel native.** `google_maps_flutter` embeds the *real* native Google Map view (platform view), not an HTML canvas. Autocomplete, polyline route drawing, and camera-fit animation ([booking_search_screen.dart](DHC_transport/lib/screens/booking_search_screen.dart)) run at native frame rates. A **PWA cannot embed the native Maps SDK**, and iOS Safari throttles background JS, breaks `speech_to_text`-style mic access, and can't do real push. So a PWA was ruled out by the mic (voice AVA) and the native map.
3. **Why not Next.js / a web app at all?** Next.js is a *server-rendered web* framework — it targets browsers, not app stores. Carthage Transfer needs an installable mobile app (airport travellers, on-the-go booking, home-screen presence, notifications). Next.js would give a website, not an app; you'd still need React Native or Flutter for the mobile artifact. Flutter delivers the store-installable Android/iOS build directly.
4. **Why not React Native?** RN bridges to platform widgets and leans on a large JS dependency tree; Flutter compiles Dart to native ARM and paints its own widgets with Skia/Impeller, which is why this heavily-custom "luxury" UI (custom bottom nav, glassmorphism `BackdropFilter`, hand-painted map placeholder in [premium_client_components.dart](DHC_transport/lib/shared/widgets/client/premium_client_components.dart)) renders identically on every device. Pixel-exact control of a bespoke design system is far easier in Flutter's single rendering pipeline.
5. **Fast iteration for a solo dev / PFE timeline.** Hot reload + a single language (Dart) for both apps meant the entire two-audience product was buildable by one person.

One-line answer to memorise: *"Flutter gives me one Dart codebase that compiles to true-native Android and iOS, embeds the native Google Maps SDK and the microphone that AVA needs, and paints a fully custom luxury design system identically everywhere — none of which a PWA or a Next.js website can do, and without the 4-codebase cost of going native twice."*

---

## 2. State Management (⭐ the question you failed last time — study this hardest)

**There is no third-party state-management library.** The app uses **four native Flutter mechanisms**, each for a specific scope. Being able to name the four and say *why each* is the whole game.

### 2.1 The four mechanisms

**(a) Singleton service + `ValueNotifier`, consumed by `ValueListenableBuilder` — for global, app-wide reactive state (theme & language).**

- [theme_service.dart](DHC_transport/lib/core/services/theme_service.dart): a private-constructor singleton (`ThemeService._()` + `static final instance`). It exposes `final ValueNotifier<ThemeMode> mode`. Calling `setDark(bool)` updates `mode.value` and persists to `SharedPreferences`.
- [language_service.dart](DHC_transport/lib/core/services/language_service.dart): same pattern, `final ValueNotifier<AppLanguage> language` (enum `{english, french}`).
- In [main.dart:29-34](DHC_transport/lib/main.dart#L29) the *entire* `MaterialApp` is wrapped in **nested `ValueListenableBuilder`s** — outer listens to `ThemeService.instance.mode`, inner to `LanguageService.instance.language`. When either notifier's `.value` changes, only that builder subtree rebuilds, swapping `themeMode`/`locale` and rebuilding the whole app with the new theme/language. This is how a theme or language toggle **instantly re-skins/re-translates every screen** with no navigation.

**(b) `StatefulWidget` + `setState` — for local, ephemeral screen state.**

This is the dominant pattern for screens. Examples: the selected tab index in [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart) (`_ClientShellState._index`), the booking form fields in [booking_search_screen.dart](DHC_transport/lib/screens/booking_search_screen.dart) (`_tripType`, `_passengers`, `_departureDate`, autocomplete lists…), filter tab in the Bookings tab, etc. `setState` rebuilds just that widget.

**(c) `ChangeNotifier` + manual listener — for a controller that owns a chat session.**

[assistant_controller.dart](DHC_transport/lib/screens/assistant/assistant_controller.dart) — `AssistantController extends ChangeNotifier`. It holds `_messages`, `_isTyping`, `_isSending`, calls `notifyListeners()` (guarded by a `_disposed` flag) as SSE events arrive. The screen attaches with `_ctrl.addListener(_onUpdate)` in `initState` and calls `setState` in the listener ([assistant_screen.dart:52,66](DHC_transport/lib/screens/assistant_screen.dart#L52)). This is the classic "controller separate from widget" split — the streaming/business logic lives in the ChangeNotifier, the widget only renders.

**(d) `FutureBuilder` — for one-shot async loads.**

Screens that fetch once (bookings history + pricing rules, rewards, admin dashboard) use `FutureBuilder` over a `Future` stored in state, e.g. `_BookingsTab` in [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart) builds `_future = _load()` in `initState`, renders skeletons while `ConnectionState.waiting`, and calls `setState(() => _future = _load())` to refresh. The admin dashboard ([admin_dashboard_screen.dart](DHC_transport/lib/features/admin/presentation/admin_dashboard_screen.dart)) loads with `initState → _load()` into plain `setState` fields.

**Bonus — `AuthService` is a *non-reactive* singleton.** [auth_service.dart](DHC_transport/lib/core/services/auth_service.dart) is a singleton like the others but exposes plain getters (`currentUser`, `token`, `isAuthenticated`), **not** a `ValueNotifier`. It's read imperatively (`AuthService.instance.currentUser`). Login/logout navigate to a fresh route rather than reactively rebuilding, so it doesn't need to notify. Be ready for the follow-up: *"why is Auth not reactive?"* → because auth transitions always coincide with a full-screen route change (`pushNamedAndRemoveUntil`), so there's nothing to reactively rebuild in place.

### 2.2 How the app reacts to theme / language changes (exact chain)

1. User toggles → `ThemeService.instance.setDark(true)` (or `LanguageService.instance.setLanguage(...)`).
2. That sets `mode.value` / `language.value` → the `ValueNotifier` fires.
3. The root `ValueListenableBuilder` in [main.dart](DHC_transport/lib/main.dart) rebuilds `MaterialApp` with new `themeMode` / `locale`.
4. `AppColors.setDarkMode(...)` is called in the builder ([main.dart:35](DHC_transport/lib/main.dart#L35)) so the global color getters flip (see §8), and `Intl.defaultLocale` is updated for date formatting.
5. Every screen rebuilds against the new `Theme.of(context)` and new `LanguageService.t(...)` strings.

State is **persisted** via `SharedPreferences` in each service's `setX` and reloaded on launch in `main()` via `await Future.wait([...loadFromStorage()])` ([main.dart:15-19](DHC_transport/lib/main.dart#L15)).

**One-line answer:** *"Global reactive state (theme, language) is a singleton service exposing a `ValueNotifier`, consumed by a `ValueListenableBuilder` that wraps the whole `MaterialApp`; per-screen state is `StatefulWidget`/`setState`; the AVA chat uses a `ChangeNotifier` controller; async fetches use `FutureBuilder`. No Provider/BLoC/Riverpod — the app is small enough that Flutter's built-ins are the right tool, and adding a DI/state library would be over-engineering."*

---

## 3. Widget Architecture & Navigation

### 3.1 Folder structure (two conventions living together)

`lib/` mixes an **older flat layout** and a **newer feature-first layout** — worth acknowledging as organic growth:

- `lib/core/` — cross-cutting: `constants/` (colors, maps key), `models/`, `routing/`, `services/`, `theme/`, `utils/`.
- `lib/features/<feature>/presentation/` — **feature-first** (admin, auth, destination_guide, notifications, recommendations).
- `lib/screens/` — **older flat screens** (booking flow, assistant, client shell).
- `lib/shared/widgets/` — reusable widgets grouped by audience (`admin/`, `client/`, `common/`).
- `lib/widgets/`, `lib/models/`, `lib/data/` — legacy home for widgets/models/static seed data.

### 3.2 Navigation pattern — **Navigator 1.0 with named routes** (not GoRouter, not Navigator 2.0)

- Routes are string constants in [app_routes.dart](DHC_transport/lib/core/routing/app_routes.dart) (`/auth`, `/login`, `/client`, `/admin`, `/assistant`, …).
- A central **`onGenerateRoute`** factory in [app_router.dart](DHC_transport/lib/core/routing/app_router.dart) maps each name to a `MaterialPageRoute`, including argument parsing (e.g. `clientShell` reads an `int` initial-tab index; `destinationGuide` reads a `String`).
- Wired in [main.dart:57](DHC_transport/lib/main.dart#L57): `onGenerateRoute: AppRouter.onGenerateRoute`, with `initialRoute` chosen by auth + role.
- Everything else is **imperative**: `Navigator.of(context).push(MaterialPageRoute(...))` for deeper screens (e.g. `_startBooking` → `BookingFleetScreen` in [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart)), and `pushNamedAndRemoveUntil(AppRoutes.login, ...)` to reset the stack on logout.

Be ready to defend: *"Why not GoRouter?"* → No deep-linking / web-URL requirements, no nested route state to sync; a named-route table + `onGenerateRoute` is the standard, dependency-free Navigator 1.0 approach and is sufficient for a push/pop mobile flow.

### 3.3 Shells & bottom navigation (the "app skeleton")

Both apps use a **shell + `IndexedStack`** pattern so tabs keep their state when you switch:

- **Client:** [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart). `_ClientShellState` holds `_index`, builds a `List<Widget> tabs` (Home, Bookings/Trips, Favorites/Saved, Notifications/Alerts, Profile) and renders `IndexedStack(index: _index, children: tabs)`. `IndexedStack` keeps **all five tabs alive** (their scroll position and state persist) and just shows one. Tab switching is `setState(() => _index = value)` — **not** navigation. An unread-notification count flows up from the Notifications tab via a callback and drives a badge on the Alerts item.
- **Admin:** [admin_shell.dart](DHC_transport/lib/features/admin/presentation/admin_shell.dart). Same idea, 4 tabs (Dashboard, Bookings, Fleet, Profile), `IndexedStack`, `setState`. Secondary screens (Promotions, Pricing, Complaints) are `push`ed on top rather than being tabs.

The **bottom nav bars are fully custom widgets**, not `BottomNavigationBar`/`NavigationBar`:
- Client uses **`PremiumClientNav`** in [premium_client_components.dart](DHC_transport/lib/shared/widgets/client/premium_client_components.dart). It is a floating, pill-shaped, **glassmorphic** bar: `SafeArea` → `ConstrainedBox(maxWidth:440)` → `ClipRRect` + `BackdropFilter(blur 18)` + translucent fill and border. The selected item **animates wider** to reveal its text label (`AnimatedContainer` width interpolation + `AnimatedOpacity`/`AnimatedSlide` on the label), the icon slides from centered to left, and there's a red dot badge for unread alerts. Uses a `LayoutBuilder` to compute active vs compact item widths responsively.
- Admin uses **`LuxuryBottomNav`** (`LuxuryBottomNavItem` list) from `shared/widgets/common/luxury_components.dart`.

### 3.4 Reusable / custom widgets (there are many — name a few)

- `shared/widgets/common/luxury_components.dart` — `LuxuryCard`, `LuxuryBackdrop`, `LuxuryBottomNav` (the app-wide design primitives).
- `shared/widgets/client/premium_client_components.dart` — `PremiumGlassPanel`, `PremiumClientNav`, `PremiumPrimaryButton`, `PremiumIconButton`, `PremiumAvatar`, `PremiumMapPreview` (a hand-painted `CustomPainter` fake-map used where a live map isn't needed).
- `shared/widgets/common/` — `auth_background.dart`, `auth_brand_logo.dart`, `auth_primary_button.dart`, `custom_auth_textfield.dart`, `route_map_view.dart`, `map_placeholder.dart`.
- `widgets/common/` — `fallback_network_image.dart` (network image with graceful fallback, used for avatars/vehicles), `luxury_skeleton.dart` (`SkeletonCardList` shimmer placeholders), `luxury_cta.dart`.
- AVA card widgets in `screens/assistant/widgets/` — `confirmation_card.dart`, `selection_card.dart`, `result_card.dart`, `analytics_card.dart`, `assistant_message_bubble.dart`, `user_message_bubble.dart`, `typing_indicator.dart`, `ava_avatar.dart`.

Composition style is **plenty of small private widget classes** (`_HomeHero`, `_WhereToCard`, `_BookingCard`, `_RouteLine`, `_TripStatusBadge`, …) rather than deep helper methods — a `build()` reads like a layout tree of named parts.

---

## 4. Localization / Internationalization (⭐ another failed question)

### 4.1 It is a **custom key/value dictionary**, NOT `.arb` / `gen_l10n` / `intl` message extraction

- The translations live in a **hardcoded Dart `const Map`** named `_strings` at the bottom of [language_service.dart](DHC_transport/lib/core/services/language_service.dart) — `{'en': {...}, 'fr': {...}}` with ~180 keys each (`'home'`, `'my_rides'`, `'booking_cancel_limit'`, …).
- Lookup is a method `String t(String key, {Map<String,Object>? args})` ([language_service.dart:51](DHC_transport/lib/core/services/language_service.dart#L51)): it reads `_strings[code]?[key]`, falls back to English, then to the raw key, and does **placeholder interpolation** by replacing `{name}` tokens from `args` (e.g. `l.t('booking_minimum', args: {'hours': 3})`).
- Usage in UI: `final l = LanguageService.instance; ... Text(l.t('my_rides'))` — seen throughout [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart).

So strings are **centralised** (not hardcoded-with-conditionals scattered in widgets) but managed by a **home-grown translation table**, not the Flutter `intl`/ARB toolchain.

### 4.2 What `flutter_localizations` + `intl` are actually for here

- `flutter_localizations` is included **only** to localize the **built-in Material/Cupertino widgets** (the date picker, time picker, month names, etc.) — via the three delegates (`GlobalMaterialLocalizations`, `GlobalCupertinoLocalizations`, `GlobalWidgetsLocalizations`) and `supportedLocales: [Locale('en'), Locale('fr')]` in [main.dart:40-48](DHC_transport/lib/main.dart#L40). It does **not** translate your own strings.
- `intl` is used for **date/number formatting** (`DateFormat` in booking screens / [pricing_service.dart](DHC_transport/lib/core/services/pricing_service.dart)) and for `Intl.defaultLocale` (set to `fr_FR`/`en_US` in `LanguageService.loadFromStorage`/`setLanguage`).

### 4.3 How EN/FR switching works end-to-end

`LanguageService` holds `ValueNotifier<AppLanguage> language`. `setLanguage()` updates it, sets `Intl.defaultLocale`, and persists `'app_language'` to `SharedPreferences`. The root `ValueListenableBuilder<AppLanguage>` in [main.dart](DHC_transport/lib/main.dart) rebuilds `MaterialApp` with `locale: Locale(code)`, and every `l.t(...)` call now returns French. Some subtrees (e.g. `ClientShell.build`) *also* wrap in their own `ValueListenableBuilder<AppLanguage>` to be safe.

**Honesty flag to mention:** the accented French text in `_strings` is written **without diacritics in some entries** (e.g. `'Aeroport'`, `'reservee'`, `'a l instant'`) — a pragmatic choice to avoid encoding issues, not a bug, but be ready to note it.

**One-line answer:** *"Localization is a custom in-memory dictionary: `LanguageService.t(key, {args})` looks the key up in a hardcoded `{en, fr}` map with English fallback and `{token}` interpolation. `flutter_localizations` is only there to translate the native date/time pickers, and `intl` only formats dates. Switching language flips a `ValueNotifier` that rebuilds the whole app. I chose a hand-rolled table over the ARB/gen-l10n toolchain because with two languages and one developer it's simpler and needs no codegen — the trade-off is I lose ICU pluralization/gender and compile-time key checking."*

---

## 5. Google Maps Integration

Three concerns split across three files, all keyed by `kMapsApiKey` in [maps_config.dart](DHC_transport/lib/core/constants/maps_config.dart).

⚠ **Security flag (very important to know before the jury):** `maps_config.dart` **hardcodes the Google Maps API key in committed source** (`const kMapsApiKey = 'AIza...'`). The comment claims it "mirrors android/local.properties (gitignored)", but the constant itself is in git. The Flutter app calls the Google Places & Directions **web** APIs **directly from the device** with this key. Mitigation you should state: this key must be restricted (Android app signing SHA + API restrictions) in the Google Cloud console, and ideally the Places/Directions calls should be **proxied through the backend** (the backend already has `settings.maps_api_key`) so the key never ships in the app. See §Part 5 "what I'd improve".

### 5.1 Places Autocomplete + Details

[places_service.dart](DHC_transport/lib/core/services/places_service.dart) — a thin `http` wrapper around `https://maps.googleapis.com/maps/api/place`:
- `autocomplete(input)` → `GET /autocomplete/json?input=...&components=country:tn&language=en&key=...`. Requires ≥2 chars, restricts to **Tunisia** (`country:tn`), returns up to **5** `PlaceSuggestion(description, placeId)`, and **swallows all errors** (returns `[]`) so a failed suggestion never breaks the form.
- `getCoordinates(placeId)` → `GET /details/json?place_id=...&fields=geometry&key=...` → returns a `LatLng` (only fetches geometry to keep the call cheap).

### 5.2 Directions & polyline

[directions_service.dart](DHC_transport/lib/core/services/directions_service.dart):
- `getRoute(origin, dest)` → `GET .../directions/json?origin=...&destination=...&mode=driving&key=...`, reads `routes[0].overview_polyline.points`.
- Decodes it with the **standard Google encoded-polyline algorithm** implemented by hand (`_decode`, the ~15-line bit-shift loop) into `List<LatLng>`. Returns `[]` on any failure (silent — the map just shows no line).

### 5.3 How it comes together on the booking screen

[booking_search_screen.dart](DHC_transport/lib/screens/booking_search_screen.dart) is the showcase screen:
- A full-screen `GoogleMap` (with `EagerGestureRecognizer` so the map wins gestures over the draggable sheet) sits behind a `DraggableScrollableSheet` form.
- Typing in pickup/destination fields triggers a **400 ms `Timer` debounce** (`_onPickupChanged`/`_onDestChanged`) before calling `PlacesService.autocomplete` — avoids a request per keystroke.
- Selecting a suggestion calls `getCoordinates`, stores `_pickupLatLng`/`_destLatLng`, then **non-blockingly** fetches the road route (`_fetchRoute` → `DirectionsService`) and animates the camera to fit both points (`_fitBounds` with `CameraUpdate.newLatLngBounds`).
- Markers (green pickup, orange destination) come from the `_markers` getter; the gold route line from the `_polylines` getter (color `0xFFC8A96B`, width 5).
- Coordinates fall back to a local gazetteer, `TnLocations.resolve(text)` (`lib/core/utils/tn_locations.dart`), so well-known Tunisian places resolve even without a Places lookup, and the default pickup is pre-filled as "Tunis-Carthage Airport (TUN)".

### 5.4 How coordinates travel between screens

The search screen packs everything (including `pickupLat/Lng`, `destinationLat/Lng`) into a **`BookingData`** model ([models/booking_data.dart](DHC_transport/lib/models/booking_data.dart)) and hands it to the next screen via the `onSearch` callback → `BookingFleetScreen(data: data)`. Those coordinates are what power the **real server-side price quote**: `PricingService.realEstimates(data)` posts them to `POST /bookings/price-estimate` ([pricing_service.dart:155](DHC_transport/lib/core/services/pricing_service.dart#L155)). `BookingData.hasCoordinates` gates whether the real quote is even attempted.

---

## 6. AVA Chat UI (Flutter side)

### 6.1 Screen states

[assistant_screen.dart](DHC_transport/lib/screens/assistant_screen.dart) — a `StatefulWidget` with two visual states swapped by an `AnimatedSwitcher` (250 ms fade):
- **Lounge** (zero messages): framed AVA portrait on a backlit radial "stage light" with a one-time entrance animation (`_ConciergeLounge`, an `AnimationController` fade+scale+vignette, played once per app session via a static flag), a time-based greeting, and horizontal **suggestion chips** (`_SuggestionChips`) that send a canned first message on tap.
- **Conversation**: a `ListView` of message bubbles + a `TypingIndicator`. Auto-scrolls to bottom via `WidgetsBinding.instance.addPostFrameCallback`.
- A fixed bottom **`_InputBar`** (mic + text pill + send) overlays both.

### 6.2 SSE streaming on the Flutter side

- Transport: [assistant_api_service.dart](DHC_transport/lib/core/services/assistant_api_service.dart). It builds an `http.Request('POST', /assistant/chat)` with `Accept: text/event-stream` and the **JWT Bearer** token, sends it, then pipes the response stream through `utf8.decoder` → `LineSplitter`, keeps only lines starting with `data:`, JSON-decodes each, and **`yield`s** it as a `Stream<Map<String,dynamic>>`. It stops on a `done` or `error` event. The `thread_id` is a stable per-user id stored in `SharedPreferences` (`getOrCreateThreadId()`), so a conversation resumes across app launches.
- Consumption: [assistant_controller.dart](DHC_transport/lib/screens/assistant/assistant_controller.dart) `sendMessage()` `await for`s the stream. Event types handled:
  - `token` → keep-alive pulse; nothing rendered, typing indicator stays.
  - `analytics` → **stashed** in `pendingAnalytics` (arrives just before `done`).
  - `done` → if analytics was stashed, append a `ChatMessage.analytics(...)`; otherwise append `ChatMessage.assistantParsed(text)` (runs the card parser).
  - `error` → append `ChatMessage.error(...)` with `_friendlyError()` mapping.
  - A safety net clears loading flags if the stream ends without `done`/`error`.

⚠ **Streaming is node-level, not token-level.** The backend emits one event per graph node + a keep-alive tick; it does **not** stream tokens (see backend §Part 4). So the Flutter side shows a typing indicator, then the *whole* answer appears at `done`. `AssistantMessageBubble` then does a **client-side typewriter animation** over the final text (`animate: msg.shouldStream && !hasStreamed(id)`) to *look* streamed. Be honest about this if asked.

### 6.3 The 4 card types — parsed client-side from plain text

⚠ **Key architectural point:** the backend sends **plain text**; the Flutter side *classifies that text into cards*. The backend contract is unchanged — cards are a pure presentation layer.

- Type model: [ava_card_data.dart](DHC_transport/lib/screens/assistant/ava_card_data.dart) — `enum AvaCardType { none, confirmation, selection, result, info }` plus payload classes (`ConfirmationCardData`, `SelectionCardData`, `ResultCardData`, `InfoCardData`).
- Parser: [ava_card_parser.dart](DHC_transport/lib/screens/assistant/ava_card_parser.dart) — `AvaCardParser.parse(raw)` tries, in order:
  1. **Result** — text starting with `Done — …` or `I wasn't able to …` / `I apologize — something went wrong` → success/cancelled/failed status.
  2. **Confirmation** — detects the backend's exact `Reply **yes** to confirm` phrasing (requires the markdown bold), strips the instruction, extracts route/when detail rows.
  3. **Selection** — a numbered list (≥2 `1. … 2. …` lines) + prompt; each option sends back its ordinal digit.
  4. **Info** — prose containing `**bold**` runs.
  5. else **plain** bubble. Any exception → plain (a card must never crash chat).
- The **analytics card is different** — it is NOT parsed from text; it's built from the structured `analytics` SSE event and carried on `ChatMessage.analyticsData`. Rendered by [analytics_card.dart](DHC_transport/lib/screens/assistant/widgets/analytics_card.dart) using **`fl_chart`**: a horizontal KPI tile row, the analyst narrative, then line/area/bar/pie charts built from the backend's chart spec dicts (`type`, `title`, `data:[{label,value}]`, `color_scheme`, `highlight`), then insight bullets.

⚠ **Stale-comment flag:** `ChatMessage.assistantParsed`'s doc comment says *"Not wired into the live flow yet"* ([chat_message_model.dart:61](DHC_transport/lib/screens/assistant/chat_message_model.dart#L61)) — but the controller **does** call it on every `done` event. The comment is outdated; the parser IS live.

### 6.4 Speech-to-text

In `_InputBarState` ([assistant_screen.dart](DHC_transport/lib/screens/assistant_screen.dart)): a `SpeechToText` instance. Tapping the mic calls `_speech.initialize()` then `_speech.listen(onResult: ...)` and writes recognized words straight into the text controller (`listenFor: 30s`, `pauseFor: 3s`, `cancelOnError`). Haptic feedback + a gold pulsing mic while listening. Result text is sent through the **same** `_send` path as typed input.

---

## 7. HTTP Client Architecture

### 7.1 One central client

[transport_api_client.dart](DHC_transport/lib/core/services/transport_api_client.dart) — a singleton `TransportApiClient.instance` wrapping a single `http.Client`.
- **Base URL resolution** (`defaultBaseUrl`): honors a `--dart-define=DHC_API_BASE_URL` override; else `http://10.0.2.2:8000/api/v1` on Android emulator (10.0.2.2 = host loopback), `http://127.0.0.1:8000/api/v1` on web/desktop. `mediaBaseUrl` strips `/api/v1` for serving uploaded avatars.
- **Methods**: `get/post/put/patch/delete` all funnel into one private `_send(method, path, {query, body})` that uses a Dart 3 `switch` expression to pick the verb, JSON-encodes the body, sets headers, and **12-second timeout**. `postMultipart` handles avatar upload (`MultipartRequest`, 20 s timeout).
- **Responses**: decodes JSON (empty body → `{}`); on non-2xx it throws a `TransportApiException(detail)` reading the backend's `detail` field.

### 7.2 How the JWT is attached

`setToken(String?)` stores the token in a private `_token`. Every request adds `if (_token != null) 'Authorization': 'Bearer $_token'`. The token is set at three moments: on app start (`AuthService.loadFromStorage` reads it from `SharedPreferences` and calls `setToken`), on login/signup (from the auth response), and cleared on logout. So the client is stateful about auth and the services above it never touch headers.

### 7.3 Service layer on top

Each domain has a thin service that calls the client and maps JSON → typed models: `AuthService`, `TripService` (bookings CRUD, `/bookings/history`, status/cancel/approve), `PricingService` (real estimates + local rules), `RewardService`, `NotificationService`, `FavoriteService`, `SupplierService`, `VehicleCatalogService`, `AssistantApiService` (SSE, uses its own `http.Client`), plus the Maps services (which call Google directly, not the client). Models expose `fromJson` factories (e.g. `TransportTrip.fromJson`, `PricingRules.fromJson`).

### 7.4 Client-side error handling

- Network/HTTP errors surface as `TransportApiException` with the server `detail`, shown to the user via `SnackBar` or inline messages, and often **swallowed to a safe default** (e.g. `PricingService.rules()` returns `const PricingRules()` defaults on failure; `PlacesService`/`DirectionsService` return empty; `FavoriteService` falls back to defaults). Timeouts produce a friendly *"Could not reach the server…"* message. The philosophy is **graceful degradation** over hard failures.

---

## 8. Theming

### 8.1 Two mechanisms working together

1. **A `ThemeData` per brightness** — [app_theme.dart](DHC_transport/lib/core/theme/app_theme.dart) `AppTheme.lightTheme()/darkTheme()` both call one private `_theme(brightness:)`. It's **Material 3** (`useMaterial3: true`), seeds a `ColorScheme.fromSeed(seedColor: gold)`, and heavily customizes dialogs, date/time pickers, inputs, cards, and the `NavigationBar`. Text theme is `GoogleFonts.montserratTextTheme()` recolored to `AppColors.textPrimary`.
2. **A mutable global color palette** — [app_colors.dart](DHC_transport/lib/core/constants/app_colors.dart). `AppColors` holds a `static bool _isDark` and exposes **getters** (`background`, `surface`, `textPrimary`, …) that return a dark or light value based on `_isDark`. `AppColors.setDarkMode(bool)` flips it. This is called from the root builder ([main.dart:35](DHC_transport/lib/main.dart#L35)) and defensively inside many `build()`s (`AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark)`).

⚠ Flag: this dual system (a real `ThemeData` **and** a global mutable `AppColors`) is redundant and slightly fragile — `AppColors` is a global singleton, so a widget that reads `AppColors.surface` without first syncing `_isDark` could theoretically read a stale value. The code guards against it by calling `setDarkMode` at the top of screens. A cleaner design would drop `AppColors` in favour of `Theme.of(context).colorScheme` + a `ThemeExtension`.

### 8.2 The exact palette (dark / light)

From [app_colors.dart](DHC_transport/lib/core/constants/app_colors.dart):

| Token | Dark | Light |
|---|---|---|
| `primary` (near-black) | `#030303` | `#030303` |
| `secondary` (**signature gold**) | `#C8A96B` | `#C8A96B` |
| `secondaryDark` | `#8E7745` | — |
| `secondaryLight` | `#E0C68A` | — |
| `background` | `#020202` | `#FAF7EF` (ivory) |
| `surface` | `#101010` | `#FFFEFA` |
| `surfaceElevated` | `#1B1B1B` | `#F3ECDE` |
| `textPrimary` | `#FFFCF3` | `#15120D` |
| `textSecondary` | `#D8D1C4` | `#4E473D` |
| `textMuted` | `#918B80` | `#7E766B` |
| `danger` | `#B24B4B` | same |

Accent status colors: `green #27AE60`, `blue #4A90D9`, `purple #7B5EA7`, `teal #00A896`, `whatsapp #25D366`. **Default theme mode is DARK** (`ThemeService.mode = ValueNotifier(ThemeMode.dark)`, and `loadFromStorage` defaults `dark = true`). The AVA screen additionally hardcodes its own near-black/gold tokens locally.

### 8.3 Typography

**Montserrat**, loaded at runtime via `google_fonts` (no `.ttf` bundled). Weights used across the UI range from `w300` (AVA hero) to `w800` (headings, prices, labels); small uppercase gold labels with wide `letterSpacing` (2–3) are the recurring "luxury" motif.

---

## 9. Key Screens Deep Dive

### 9.1 Booking flow (in order)

1. **Search** — [booking_search_screen.dart](DHC_transport/lib/screens/booking_search_screen.dart): full-screen map + draggable form (trip type, pickup/dest with Places autocomplete, date/time pickers, passenger/luggage counters). Validates presence + **minimum-booking-hours** (`PricingService.respectsMinimumBooking`) before emitting a `BookingData`.
2. **Fleet** — [booking_fleet_screen.dart](DHC_transport/lib/screens/booking_fleet_screen.dart): shows vehicles with the **real per-vehicle quote** from `PricingService.realEstimates()` (→ `POST /bookings/price-estimate`), falling back to the local rules-based `estimate()` if coordinates/network fail.
3. **Contact** — [contact_confirmation_screen.dart](DHC_transport/lib/screens/contact_confirmation_screen.dart): passenger/contact details.
4. **Payment** — [payment_method_screen.dart](DHC_transport/lib/screens/payment_method_screen.dart): cash vs card (card is a placeholder — see backend §Part 2.4).
5. **Confirmation** — [booking_confirmation_screen.dart](DHC_transport/lib/screens/booking_confirmation_screen.dart): review + submit → `TripService.createBooking(payload)` → `POST /bookings/`.
6. **Success** — [booking_success_screen.dart](DHC_transport/lib/screens/booking_success_screen.dart).

Modify/cancel live inside the Trips tab in [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart) (`_ModifyBookingScreen`, `_CancelBookingScreen`), gated client-side by `PricingService.canChangeBooking(date, time, limitHours)` and enforced again server-side.

### 9.2 Admin dashboard

[admin_dashboard_screen.dart](DHC_transport/lib/features/admin/presentation/admin_dashboard_screen.dart):
- Loads **three** endpoints on `initState`, each best-effort: `GET /admin/overview` (stat tiles), `GET /analytics/dashboard` (rich analytics — degrades silently if it fails), and `TripService.listTrips()` filtered to `isPendingApproval` (pending **cash approvals**).
- Renders: **Pending Cash Approvals** carousel (tap → bottom sheet → `approvePayment` → `PATCH /admin/bookings/{id}/approve-payment`); a **stat-tile `Wrap`** (total bookings/clients/vehicles/pending/open complaints); Revenue card, 7-day trend **bar chart** (hand-built bars, not fl_chart), Popular destinations, a status **breakdown** with `LinearProgressIndicator`s; and a Quick-actions list (Bookings/Fleet/Promotions/Pricing/Complaints).
- Data source objects come straight from Mongo aggregation (see §Part 4.5).

### 9.3 Profile tab — the "Carthage Privilège" membership card

The `_MembershipCard` widget in [client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart#L2877):
- A dark-lacquer gradient card (`#191510 → #0C0A07`) with a gold border and shadow — styled as a physical loyalty card, labelled **"CARTHAGE PRIVILÈGE"**.
- Reads a best-effort `rewards` map (`tier`, `completed_trips`, `points` [= `completed*10` fallback], `next_tier`, `next_tier_threshold`) sourced from `RewardService.getRewardsMe()` → `GET /rewards/me`.
- Shows the **tier badge**, big **points** number, a gold `LinearProgressIndicator` of progress to the next tier, and a `"{n} RIDES TO {NEXTTIER}"` line (or `"TOP TIER"`). Tapping opens the full `_RewardsScreen` (`_TierSummaryCard`, promo cards). Points/tier math mirrors the backend `get_user_promos` tool (Bronze/Silver/Gold/Black at 0/50/150/300 points, 10 pts/trip).

---

## 10. pubspec.yaml full audit

See the table in §1.1 for the complete list with roles and resolved versions. Summary for the jury:
- **9 runtime dependencies + 2 Flutter SDK packages + 1 dev lint package.** Deliberately lean.
- **No dead dependencies** — every one is imported somewhere in `lib/`.
- **Notable *absences* (and why they're fine):** no state-management lib (native primitives suffice, §2), no `dio` (the hand-written `http` client suffices, §7), no `firebase_*` (auth is the custom JWT backend), no local push-notification plugin (notifications are **in-app**, fetched from `/notifications/`, not OS push — say this clearly), no `flutter_secure_storage` (⚠ the JWT sits in plain `SharedPreferences` — an improvement to name).
- SDK constraint: Dart `>=3.3.0 <4.0.0`.

---

# PART 2 — BACKEND (FastAPI)

## 1. Project structure

`backend/app/` ([main.py](backend/app/main.py) is the entrypoint):
- `main.py` — `create_app()`: CORS, startup/shutdown hooks (`connect_to_mongo`, `ensure_indexes`, RAG freshness log), mounts `/media` static files, includes the v1 router, `/health`.
- `core/` — `config.py` (Pydantic-Settings), `database.py` (Motor async client), `security.py` (JWT + password hash), `deps.py` (auth dependencies).
- `api/v1/api.py` — the master `APIRouter` including 15 endpoint routers. `api/v1/endpoints/*.py` — one module per domain.
- `services/` — business logic (`auth_service`, `booking_service`, `pricing_calculator`, `analytics_service`, `destination_service`, `profile_media_service`, `utils`).
- `models/documents.py` — Pydantic document models. `schemas/dtos.py` — request/response DTOs.
- `db/` — `indexes.py`, `seed.py`, `fleet_data.py`.
- `ai/` — the entire AVA system (see Part 4).

Stack: **FastAPI + Motor (async MongoDB) + Pydantic v2 + python-jose (JWT) + passlib (pbkdf2_sha256) + LangGraph/LangChain + Google Gemini + Chroma + HuggingFace embeddings.**

## 2. Every endpoint

Mounted under `/api/v1` ([api.py](backend/app/api/v1/api.py)). Auth column: 🔓 public, 👤 client (`require_client` — client **or** admin), 🛡 admin (`require_admin`), 🔑 any authenticated (`get_current_user`).

### auth ([auth.py](backend/app/api/v1/endpoints/auth.py)) — `/auth`
| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/login` | 🔓 | email+password → JWT (`build_token_response`) |
| POST | `/signup` | 🔓 | register client → JWT (409 if email exists) |
| GET | `/me` | 🔑 | current user payload |
| PUT | `/me` | 🔑 | update profile (email-uniqueness checked) |
| POST | `/me/avatar` | 🔑 | multipart avatar upload (jpg/png/webp) |
| POST | `/forgot-password` | 🔓 | store reset token, best-effort SMTP email |
| POST | `/reset-password` | 🔓 | consume token, set new password |

### bookings ([bookings.py](backend/app/api/v1/endpoints/bookings.py)) — `/bookings`
| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/price-estimate` | 👤 | real distance-based quote (1 or all vehicles) |
| GET | `/` | 👤 | list (admin=all, client=own), optional `booking_status` |
| GET | `/history` | 👤 | `{upcoming, past}` split |
| GET | `/{id}` | 👤 | one booking (ownership enforced) |
| POST | `/` | 👤 | create booking (min-hours enforced, promo counted) |
| PUT | `/{id}` | 👤 | modify (client: 24h window; admin: no window) |
| PATCH | `/{id}/cancel` | 👤 | cancel (window + not-already-final checks) |
| PATCH | `/{id}/status` | 🛡 | admin set status |
| DELETE | `/{id}` | 🛡 | admin delete |

### Other routers (from [api.py](backend/app/api/v1/api.py))
- **cars** `/cars` — vehicle catalog CRUD + pricing history (writes `db.pricing_history` on price edits).
- **pricing** `/pricing` — `/config` (rules), `/promo/validate`.
- **promotions** `/promotions` — promo CRUD.
- **favorites** `/favorites` — saved locations CRUD.
- **destinations** `/destinations` — destination guide + `db.recommendations` CRUD.
- **analytics** `/analytics` — `/dashboard` (admin charts data).
- **admin** `/admin` — `/overview` (stat tiles), booking approval, complaints, users.
- **notifications** `/notifications` — list/read/read-all/delete.
- **suppliers** `/suppliers` — supplier CRUD.
- **rewards** `/rewards` — `/me`, `/available-promos`.
- **config** `/config` — cities/config lookups (`db.cities`).
- **complaints** `/complaints` — complaint create/list/status.
- **assistant** `/assistant/chat` — the SSE AVA endpoint (Part 4).
- Plus `GET /health` at the app root.

## 3. Authentication flow

- **Hashing:** [security.py](backend/app/core/security.py) — passlib `CryptContext(schemes=["pbkdf2_sha256"])`. `verify_password` / `get_password_hash`.
- **Tokens:** JWT via `python-jose`, `HS256`, `{"sub": <user _id>, "exp": ...}`, 7-day expiry (`access_token_expire_minutes = 60*24*7`). `create_access_token(subject)` / `decode_access_token(token)` (returns `None` on any error — never throws).
- **Dependencies:** [deps.py](backend/app/core/deps.py) — `HTTPBearer(auto_error=False)`. `get_current_user` decodes the token, looks up `db.users.find_one({"_id": payload["sub"]})` (note: `_id` is a **string** like `user-<uuid>`, not an ObjectId), 401 on missing/invalid/unknown. `require_client` allows role ∈ {client, admin}; `require_admin` requires role == admin. **Role is enforced at the dependency layer**, so every route declares its own access level.
- **Service:** [auth_service.py](backend/app/services/auth_service.py) — `authenticate_user`, `build_token_response` (returns `access_token`, `role`, `user`), `build_user_payload` (never leaks `hashed_password`), `register_client` (creates `user-<uuid>`, default role `client`, `preferred_language="en"`, `theme_mode="dark"`).

⚠ Flags: `/forgot-password` takes `email` as a **query/body scalar** and SMTP is optional (token always stored); the `sub` claim is the raw user id (fine). `access_token_expire = 7 days` with no refresh-token rotation — long-lived tokens are a security trade-off to mention.

## 4. Booking business logic ([booking_service.py](backend/app/services/booking_service.py) + [bookings.py](backend/app/api/v1/endpoints/bookings.py))

- **Creation** (`create_trip`): generates `booking-<uuid>`, drops `None`s and the vestigial `eta_minutes`, derives **payment_status from payment_method**: `cash → pending_approval`, `card → approved` (⚠ card online payment is **not implemented**; it's treated as a non-blocking placeholder). Sets `booking_status` **and** a duplicate `status` field. Emits notifications: client "Booking received", and for cash also notifies **all admins** ("awaiting approval"). Promo `usage_count` is incremented once **at booking time** (in the route, [bookings.py:151](backend/app/api/v1/endpoints/bookings.py#L151)), not during validation.
- **Time-window rules** (`_check_time_rule` in the route): parses `departure_date`+`departure_time` across three formats, computes hours-until-departure, raises 400 if inside the limit. Applied to **create** (`minimum_booking_hours`, default 3), **modify** (`modification_limit_hours`, default 24, **clients only** — admins bypass), and **cancel** (`cancellation_limit_hours`, default 24). Rules come from `db.pricing_rules {_id:"active"}` with safe defaults.
- **Status machine:** `VALID_STATUSES = {pending, confirmed, on_route, completed, cancelled}` ([bookings.py:22](backend/app/api/v1/endpoints/bookings.py#L22)). `update_trip_status` writes both `status` and `booking_status`, and on `completed` increments the user's `completed_rides_count` (drives loyalty). `_STATUS_MESSAGES` maps each status to a client notification.
- ⚠ **Status-vocabulary inconsistency (know this):** three different status vocabularies exist — the route's `VALID_STATUSES`, the `TripStatus` enum in [documents.py](backend/app/models/documents.py) (`requested/accepted/in_progress/...`), and Flutter's badge handling (`assigned/started/arrived`). `booking_service._STATUS_MESSAGES` even references `"assigned"`, which isn't in `VALID_STATUSES`. This is legacy drift from a ride-hailing schema; the live path uses `VALID_STATUSES`.

## 5. Pricing calculator ([pricing_calculator.py](backend/app/services/pricing_calculator.py))

The **real** transfer pricing engine, mirroring the live carthage-transfer.com "Chauffeur Booking System":

```
total = initial_fee                         (initial_fee_return for return trips)
      + billed_km × per_km                  (per_km_return for return trips)
      + n_waypoints × per_waypoint
      + waypoint_minutes × per_waypoint_duration_per_min
```
where `billed_km = distance_km × 2` for return trips.

- **Distance/duration** come from `get_route_metrics()` → Google **Directions API** (`settings.maps_api_key`), summing `routes[0].legs` (so waypoints count). On any failure it falls back to **haversine × 1.3 road factor** and `distance/60 km/h` for duration. Every result is tagged `source: google_directions | haversine_fallback`.
- **Per-vehicle params** come from the car's `pricing` sub-document (see `fleet_data.py`; e.g. Comfort Sedan: `initial_fee 12.98`, `per_km 0.413` → a ~62 km Tunis→Hammamet ≈ **38.6 EUR**, matching the real site). Legacy cars without `pricing` fall back to `base_price` as a flat fee.
- **Important nuance:** the **hourly rate (`per_hour`) is deliberately NOT added** for distance transfers — the module docstring explains that adding `duration × per_hour` on top of per-km would double-bill.
- ⚠ **Contradiction to flag:** [config.py:27-29](backend/app/core/config.py#L27) comments that the backend "does not consume" `maps_api_key` — but `pricing_calculator.get_route_metrics` **does** use `settings.maps_api_key`. The comment is wrong.
- ⚠ **Two pricing engines exist:** this backend engine is **pure distance-based** (no night/weekend/last-minute surcharges). Those percentage surcharges live **only in Flutter** (`PricingService.estimateFromBase`/`estimate` in [pricing_service.dart](DHC_transport/lib/core/services/pricing_service.dart)) and in the AVA `create_booking` tool's `_compute_price` (which applies surcharges from `pricing_rules`). So the `/bookings/price-estimate` number and the surcharge-adjusted number can differ — know why.

## 6. Notification engine

There's no push service — notifications are **rows in `db.notifications`** the client polls via `/notifications/`. They're created inline by the code that causes them:
- `booking_service._push_notification(user_id, title, message, booking_id)` inserts `notif-<uuid>` (skips `guest`/empty users). `_notify_admins` fans one out to every admin.
- Triggers: booking created (client + admins for cash), status changes (`_STATUS_MESSAGES`), admin modify with new status (`bookings._push_notification`), cancel. Each is a single, well-worded message — comments note deliberate care to **avoid duplicate pushes**.

## 7. Error-handling patterns

- **HTTP errors:** raise `HTTPException(status_code, detail)`; the Flutter client reads `detail`. Common: 401 (auth), 403 (ownership/role), 404, 400 (validation/time-window), 409 (duplicate email/promo).
- **Ownership checks** are explicit in each route (`booking.user_id != current_user._id → 403`) in addition to the role dependency.
- **AVA/SSE** never leaks raw errors: any exception collapses to one friendly constant (Part 4).
- **Best-effort degradation:** analytics/approvals loads in the admin dashboard, SMTP send, Directions API — all wrapped in try/except that logs and continues.
- **Serialization:** `services/utils.serialize_document` stringifies `_id` and normalizes docs before returning.

---

# PART 3 — DATABASE (MongoDB)

Access is **async via Motor** ([database.py](backend/app/core/database.py)); DB name defaults to `carthage_transfer`. **Documents are plain dicts with human-readable string `_id`s** (`user-<uuid>`, `booking-<uuid>`, `car-comfort-sedan`, `notif-<uuid>`, `promo-<uuid>`, `sup-<uuid>`) — not ObjectIds. This is a deliberate choice that makes ids self-describing and stable across seed/rebuild.

## 1. Collections — actually 16 in the running code (⚠ not 17)

I grepped every `db.<name>` access across `backend/app` (excluding tests). The collections actually used at runtime are:

| # | Collection | Key fields (from the code that writes them) | Written by |
|---|---|---|---|
| 1 | `users` | `_id=user-…`, email (unique), full_name, role, hashed_password, phone, preferred_language, theme_mode, is_active, completed_rides_count, avatar_url | auth_service, auth.py |
| 2 | `bookings` | `_id=booking-…`, user_id, passenger_name/phone, pickup_location, destination_name/city, vehicle_class/type, departure_date/time, return_*, passenger_count, luggage_count, trip_type, total_price, dynamic_surcharge, discount_amount, promo_code, payment_method, payment_status, status, booking_status, created_at | booking_service, tools |
| 3 | `cars` | `_id=car-…`, name, model, category, seats, luggage, base_price, availability, order, image_url, `pricing{…}`, features, pricing_verified | fleet_data/seed, cars.py, manage_fleet |
| 4 | `pricing_rules` | `_id="active"`, minimum_booking_hours, modification_limit_hours, cancellation_limit_hours, night/last_minute/weekend/seasonal `{enabled,…,percentage}` | pricing.py, manage_pricing_rules |
| 5 | `pricing_history` | car_id, vehicle_name, old/new_initial_fee, changed_at | cars.py (price edits) |
| 6 | `promotions` | `_id=promo-…`, code (unique), discount_type, value, expiry_date, usage_limit, usage_count, active | promotions.py, manage_promotions |
| 7 | `favorites` | user_id, label, address, type, created_at | favorites.py |
| 8 | `notifications` | `_id=notif-…`, user_id, title, message, type, booking_id, read, created_at | booking_service, notifications.py |
| 9 | `destinations` | name, city, region, description, visible | destinations.py, seed |
| 10 | `recommendations` | destination_id, city, region, name, category, rating, visible, + rich card fields | destinations.py |
| 11 | `suppliers` | `_id=sup-…`, name, phone, email, handle, status | suppliers.py, manage_suppliers |
| 12 | `complaints` | user_id, booking_id, message, status (open/in_review/resolved) | complaints.py, submit_claim |
| 13 | `cities` | city lookup data | config.py |
| 14 | `chat_sessions` | user_id, turns[]{human, assistant, timestamp} | supervisor.session_write |
| 15 | `audit_log` | user_id, role, event (access_denied / tool_call / safety_override), tool_name, args, outcome, timestamp | supervisor, tool_registry |
| 16 | `password_resets` | token, user_id, expires_at | auth.py |

⚠ **On the "17 collections" claim:** I could only find **16** collections referenced in the application code. `models/documents.py` *also* declares Pydantic models for `DriverDocument`, `RestaurantDocument`, `HotelDocument`, `ActivityDocument`, `RecommendationDocument`, `DestinationDocument`, `TripDocument` — but at runtime only `recommendations`/`destinations` are actually accessed via `db.<name>`; there are no live `db.drivers`/`db.restaurants`/`db.hotels`/`db.activities` calls. So either a 17th collection exists only in seed/docs, or the count in older docs is aspirational. **Be honest: "16 collections are actively used; a few more are modelled but not wired."** (If the jury insists on 17, the extra is likely one of the destination-guide sub-collections or `drivers`, kept from the original ride-hailing schema.)

## 2. Indexes ([indexes.py](backend/app/db/indexes.py))

Created on startup by `ensure_indexes()`:
- `users.email` **unique**
- `bookings`: compound `(user_id, created_at desc)`, `(status, created_at desc)`, `(guest_email, created_at desc)`
- `favorites`: `(user_id, created_at desc)`
- `notifications`: `(user_id, created_at desc)` and `(user_id, read)`
- `promotions.code` **unique**
- `destinations`: `(city, region)`
- `cars`: `(category, availability)`

These match the hot query paths (a user's bookings newest-first, admin status filters, unread-notification counts, promo lookup by code, available cars by category).

## 3. Relationships (referenced, not embedded)

MongoDB has no joins; the app uses **string foreign keys**:
- `bookings.user_id → users._id`; `notifications.user_id → users._id`, `notifications.booking_id → bookings._id`; `favorites.user_id`, `complaints.user_id`+`booking_id`, `chat_sessions.user_id`, `audit_log.user_id`, `password_resets.user_id`.
- `bookings.vehicle_class/vehicle_type` reference cars by **category/name**, not id (loose coupling).
- `pricing_rules` is a **singleton document** (`_id:"active"`). `recommendations.destination_id → destinations._id`.
Resolution is done in application code (e.g. `_notify_admins` queries `users` then inserts per-admin notifications) — there is no `$lookup` in the hot paths.

## 4. Why MongoDB (schema flexibility, with real examples)

- **Nested, per-vehicle pricing** — each `cars` doc carries a `pricing` sub-document with 8+ fields ([fleet_data.py](backend/app/db/fleet_data.py), `VehiclePricing` in [dtos.py](backend/app/schemas/dtos.py)). A relational schema would need a separate pricing table + join; here it's one embedded object read in one query.
- **Evolving booking shape** — `bookings` grew fields over time (`payment_method`, `dynamic_surcharge`, `return_date`, coordinates) with **no migrations**; new optional fields just appear. `create_trip` even strips `None`s so documents stay sparse.
- **Config as one document** — `pricing_rules {_id:"active"}` holds nested `night_pricing`/`weekend_pricing`/… objects, edited partially by `manage_pricing_rules`.
- **Heterogeneous AI logs** — `audit_log` stores different shapes per `event` type (access_denied vs tool_call vs safety_override) in one collection.
- **Human-readable ids** make seed data and debugging trivial (`car-comfort-sedan`).

One-liner: *"MongoDB lets each booking and each vehicle carry a flexible, nested, evolving shape (embedded pricing, optional payment/return fields) without migrations or joins — which fit a fast-moving PFE where the schema changed weekly and the AI writes semi-structured audit logs."*

---

# PART 4 — AI SYSTEM (AVA)

**Big picture:** AVA is a **LangGraph supervisor graph** that classifies each message into one of six domains, gates it by role, dispatches to a **domain sub-agent** (each its own compiled graph with tools), runs a deterministic **safety check**, and persists the turn — all streamed to Flutter over SSE. The LLM is **Google Gemini 2.5 Flash**. Retrieval (RAG) is **Chroma + HuggingFace MiniLM**. All of this runs **inside the FastAPI process** (no separate AI service).

## 1. Supervisor pipeline ([supervisor.py](backend/app/ai/supervisor.py)) — node by node

State is a `SupervisorState` TypedDict (`messages`, `role`, `user_id`, `domain`, `_access_denied`, `_dispatch_delta`, `_pending_ai`, `_analytics_payload`). Graph: `START → classify → gate → (dispatch → safety → session_write | session_write) → END`. Compiled with a **`MemorySaver` checkpointer** so conversation state persists across turns (required for the confirmation gate).

1. **`classify_intent_node`** — labels the message into one of six domains: `booking, support, loyalty, feedback, operations, insights`. It's defensive:
   - **Sticky confirmation:** if the last AI message was a "Reply **yes** to confirm…" prompt, it *skips* re-classification and reuses the current domain — so a "yes" doesn't get misrouted.
   - **Guard 0:** an admin using explicit business-analysis phrases (via `analysis_triggers.detect_analysis_type`) routes straight to `insights` with **no LLM call**.
   - Otherwise it calls Gemini (`invoke_with_fallback`) with `_CLASSIFY_PROMPT`, then cross-checks against a **keyword classifier** (`_keyword_classify`). Guards 1/2b force the keyword domain when a **client** hits admin-sounding words (so `role_gate` can refuse), Guard 3 reroutes interrogative "how do I cancel?" (FAQ) to `support` instead of a real cancellation. Falls back to keyword or `support`.
2. **`role_gate_node`** — pure Python. If domain ∈ {operations, insights} and role ≠ admin → writes an `audit_log` `access_denied` entry and returns a polite refusal (`_access_denied=True`). This is the **authorization boundary** for the AI.
3. **`dispatch_node`** — lazily builds & caches the domain sub-agent (`_get_sub_agent`), runs it on its **own thread** (`{thread_id}_{domain}`) so each domain keeps separate memory, passes only the latest human message (sub-agent's own MemorySaver holds history), and computes the **message delta** the sub-agent produced. Extracts the last AI text and any `analytics` payload attached by the insights agent.
4. **`safety_check_node`** — deterministic anti-hallucination guard. If the response contains success words (`confirmed/completed/cancelled/created/updated/submitted`) but **no successful `ToolMessage`** backs it (`_tool_ran_successfully`), and it isn't a confirmation prompt, it **overrides** the response with an apology and logs `safety_override` to `audit_log`. This stops the model from *claiming* it did something it didn't.
5. **`session_write_node`** — appends the `{human, assistant}` turn to `chat_sessions` (upsert per user) and adds the final `AIMessage` (carrying the analytics payload in `additional_kwargs`) to supervisor state.

## 2. The six sub-agents (each a compiled LangGraph)

Built lazily in `_get_sub_agent`. Each `build_graph()` returns a graph compiled with its own `MemorySaver`.

- **booking** ([booking_agent.py](backend/app/ai/agents/booking_agent.py)) — the most complex: a **4/5-node internal router** — `classify → (lookup | disambiguate → action | resolve_selection | action)`.
  - `lookup_node` (Gemini + read tools `get_trip_history`, `recommend_vehicle`) then a **synthesis** call turns tool JSON into concierge prose; a deterministic `_vehicle_template` is the fallback if Gemini is down.
  - `disambiguate_node` (**no LLM**) resolves a missing booking reference before any action: 0 candidates → "no bookings", 1 → auto-propose, 2+ → numbered list (`awaiting_booking_selection`). Saves Gemini quota.
  - `resolve_selection_node` (**no LLM**) maps "the 2nd one" / "the Hammamet trip" to a booking id via ordinal + destination matching.
  - `action_node` runs create/update/cancel through the **confirmation gate**.
- **support** ([support_agent.py](backend/app/ai/agents/support_agent.py)) — RAG FAQ answering via `search_knowledge_base`; can offer to perform an action (the "how do I cancel → offer to cancel" pattern).
- **loyalty** ([loyalty_agent.py](backend/app/ai/agents/loyalty_agent.py)) — points/tier/promos via `get_user_promos`.
- **feedback** ([feedback_agent.py](backend/app/ai/agents/feedback_agent.py)) — complaints via `submit_claim` (confirmation-gated).
- **operations** ([operations_agent.py](backend/app/ai/agents/operations_agent.py)) — admin fleet/pricing/suppliers/promotions, all confirmation-gated + audit-logged.
- **insights** ([insights_agent.py](backend/app/ai/agents/insights_agent.py)) — admin analytics; calls `run_business_analysis` and attaches the chart/KPI payload for the app.

### Tools — every one, with parameters

**Client tools** (8) — [tools_client.py](backend/app/ai/tools_client.py), exported as `CLIENT_TOOLS`. Each is an async `@tool`; identity (`user_id`) is bound in later and hidden from the LLM.

| Tool | LLM-visible params | Does |
|---|---|---|
| `search_knowledge_base` | `query` | RAG over the KB; returns ≤3 chunks above the 0.25 relevance floor (empty if none — so AVA admits ignorance) |
| `get_trip_history` | *(none)* | client's bookings split upcoming/past |
| `create_booking` | departure, arrival, date, time, vehicle_type, passenger_count, trip_type, passenger_name, passenger_phone, promo_code | creates booking; **price computed server-side** (`_compute_price`), LLM never sets price; enforces min-hours |
| `update_booking` | booking_id, + optional fields | modify own booking; 24h window; ownership check |
| `cancel_booking` | booking_id | cancel own booking; 24h window; not-already-final |
| `recommend_vehicle` | passenger_count, trip_type | picks best-fit vehicle using real fleet + user's last-5 preference; returns real names + est. price |
| `get_user_promos` | *(none)* | points/tier/next-tier (Bronze/Silver/Gold/Black @ 0/50/150/300, 10 pts/trip) + active promos; gaps **pre-computed** so the model doesn't do math |
| `submit_claim` | booking_id (opt), message | files a complaint |

**Admin tools** (10) — [tools_admin.py](backend/app/ai/tools_admin.py), `ADMIN_TOOLS`. No `user_id`/`role` params (they operate on the whole dataset; only handed out after role check).

| Tool | Key params | Does |
|---|---|---|
| `manage_fleet` | action(list/create/update/toggle_availability/delete) + car fields | vehicle CRUD (category ∈ Standard/VIP/Luxury/Van) |
| `manage_pricing_rules` | action(get/update) + rule fields (night/last_minute/weekend/seasonal, min/mod/cancel hours) | edit the singleton `pricing_rules` |
| `manage_suppliers` | action(list/create/update/update_status/delete) + supplier fields | supplier CRUD |
| `manage_promotions` | action(list/create/update/toggle/delete) + promo fields | promo CRUD |
| `get_dashboard_analytics` | *(none)* | booking stats, revenue by category, most-booked, popular destinations, 7-day trend (Mongo aggregation) |
| `get_admin_overview` | *(none)* | counts by status |
| `list_all_bookings` | status_filter (opt) | every booking |
| `list_users` | *(none)* | all clients (**strips `hashed_password`**) |
| `update_booking_status` | booking_id, new_status | set status directly |
| `run_business_analysis` | analysis_type, months_back | full BI: KPIs + chart specs + Gemini analyst narrative (see §5) |

## 3. RAG pipeline

- **Builder** ([build_vectorstore.py](backend/app/ai/build_vectorstore.py)): loads `ai/knowledge/*.txt`, splits with `RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)`, embeds with **`sentence-transformers/all-MiniLM-L6-v2`** (HuggingFace, local, free), persists to a **Chroma** store (collection `carthage_transfer_kb`).
- **Knowledge base** (5 files, confirmed on disk): `destinations.txt`, `faq.txt`, `pricing_policy.txt`, `terms_and_conditions.txt`, `vehicles.txt`.
- **Staleness guard:** the build writes `source_manifest.json` with a **SHA-256 per file**; on backend startup `log_freshness_on_startup()` (called from `main.py`) compares current files vs manifest and loudly warns if the index is stale (a real bug it once served — stale RAG answers). Non-blocking.
- **Retrieval** (`search_knowledge_base` in [tools_client.py](backend/app/ai/tools_client.py)): `similarity_search_with_relevance_scores(query, k=3)`. Two tuned thresholds: **relevance floor 0.25** (drop chunks below it; if nothing clears, return `[]` so the persona rule "say you don't have it" fires instead of hallucinating), and **confidence 0.50** (below it, do a **query expansion** — e.g. "airport" → "meeting the driver / name sign / free waiting time / flight delayed" — and merge results). Thresholds were derived from an observed-score audit (documented inline).

## 4. Confirmation gate ([shared.py](backend/app/ai/agents/shared.py))

The reusable `run_with_confirmation(state, model_with_tools, tool_map)` — used by booking/feedback/operations for any **state-changing** tool:
1. **Not yet awaiting:** ask the LLM (persona-prepended) to pick a tool. If it returns a tool call, **don't execute** — instead build a natural-language `format_tool_summary` ("I'd like to cancel your trip… Reply **yes** to confirm or **no** to cancel."), stash `pending_action` + set `awaiting_confirmation=True`, and return the prompt.
2. **Awaiting + user affirms** (`is_affirmation`) → execute the pending tool, emit a `ToolMessage` (internal evidence for safety_check) + a **humanized** `AIMessage` (`humanize_result`, e.g. "Done — your booking has been cancelled.") — never raw JSON.
3. **Awaiting + user negates** → cancel. **Ambiguous** → re-ask **without** re-calling the LLM.

Supporting pieces: `AVA_PERSONA_PROMPT` (the strict concierge persona — 7 rules forbidding tool names, code/JSON, and un-grounded facts); `with_persona()`; `safe_tool_args()` (filters LLM args to the tool's real schema); `resolve_proposal_state()` (enriches a toggle so the prompt can state its resulting direction). ⚠ Known TODO in the file: the operations agent routes **read-only** actions (list/get) through the gate too, so they get a needless yes/no and then drop the fetched data — flagged, not yet fixed.

## 5. Business analytics ([analytics_service.py](backend/app/services/analytics_service.py) + `run_business_analysis`)

`analytics_service` is **deterministic** (no LLM). Every method queries `bookings` (revenue = `status:"completed"`, grouped by `departure_date`, EUR). Methods:
- `get_revenue_by_month(months_back)` — revenue + count per month.
- `get_revenue_by_vehicle_category(months_back)` — revenue share % per vehicle class.
- `get_booking_volume_trend(months_back)` — weekly (ISO week) counts, all statuses (demand).
- `get_seasonal_analysis()` — peak/slow months, monthly distribution, YoY growth when ≥2 years exist.
- `get_pricing_impact_analysis()` — correlates pricing changes (`pricing_history`, else inferred from `cars.updated_at`) with booking volume **7 days before vs after**.
- `get_kpi_summary()` — MTD/YTD revenue, MoM/YoY growth, bookings MTD, avg booking value, top route, top vehicle.

`run_business_analysis` (admin tool) gathers only the data its `analysis_type` needs, builds **deterministic chart specs** (`_build_charts` → line/bar/pie/area for the Flutter `AnalyticsCard`) and **KPI tiles** (`_build_kpis`), computes **deterministic fallback insights**, then makes a **separate Gemini analyst call** (`_ANALYST_PROMPT`, <180 words) for the narrative. If Gemini fails, it **degrades to the deterministic insights** — analytics never crashes the turn. The `get_dashboard_analytics` admin tool and `GET /analytics/dashboard` feed the non-chat admin dashboard.

## 6. Safety measures (defense in depth)

1. **Role gate** in the supervisor blocks clients from admin domains and logs `access_denied`.
2. **Identity binding** ([tool_registry.py](backend/app/ai/tool_registry.py)): `_bind_user_id` rebuilds each client tool's schema **without** `user_id`, pre-filling it server-side — the LLM literally **cannot** set another user's id (prevents IDOR via the model). Ownership is *also* re-checked inside each tool.
3. **Confirmation gate** — no state-changing tool runs without explicit user "yes".
4. **Safety check node** — success claims must be backed by a real successful `ToolMessage`, else overridden + logged.
5. **Persona prompt** — forbids leaking tool/field names, code, JSON, and (rule 5) **stating any specific fact not present in the retrieved KB context** (anti-hallucination).
6. **Audit logging** — every admin tool call is wrapped by `_wrap_with_audit` (logs user, tool, args, outcome); denials and overrides logged too.
7. **Error sanitisation** — the SSE layer and `model_router` collapse **every** provider error (quota/429, Gemini errors, connection) to one friendly constant; raw errors are server-log-only (never reach the chat bubble).
8. **`list_users` strips `hashed_password`**; `build_user_payload` never returns it.

## 7. Model router ([model_router.py](backend/app/ai/model_router.py))

- **Tier 1 `CLOUD_PRIMARY`** = `ChatGoogleGenerativeAI(model="gemini-2.5-flash", temperature=0)`, created only if `GOOGLE_API_KEY` is set.
- **Tier 2 `CLOUD_FALLBACK`** = `None` — ⚠ despite the "two-tier fallback" name, **there is no second provider**. `get_model()` always returns Gemini; routing is flat regardless of task/role.
- `invoke_with_fallback(messages)` raises `RuntimeError` **immediately** if no API key; otherwise tries the chain (just Gemini) and, on exhaustion, raises a single friendly `RuntimeError` (raw error logged only). `temperature=0` → deterministic, which matters for classification and "exact-values" synthesis.

## 8. Tool registry ([tool_registry.py](backend/app/ai/tool_registry.py))

`get_tools_for_role(role, user_id)`:
- **client** → 8 client tools with `user_id` **bound and hidden** (`_bind_user_id` rebuilds a Pydantic `args_schema` minus `user_id`, wraps the coroutine to inject it). The `_NEEDS_USER_ID` set lists which tools carry identity.
- **admin** → the 8 client tools **plus** 10 admin tools, each wrapped by `_wrap_with_audit` (writes an `audit_log` `tool_call` row with args + outcome on every call).
- anything else → `ValueError`.
- Subtle engineering note in the code: it builds an explicit Pydantic model even for zero-arg tools, because leaving `args_schema=None` makes LangChain introspect `.invoke` and leak `RunnableConfig`/`args` array fields that **Gemini's strict JSON-schema rejects**.

**One-liner for the whole AI system:** *"AVA is a LangGraph supervisor: it classifies intent into six domains, gates by role (admin-only domains refuse + audit-log clients), dispatches to a domain sub-agent that calls role-scoped tools with the user's identity bound server-side, runs every state-changing tool behind a natural-language yes/no confirmation gate, cross-checks success claims against real tool evidence, and answers policy questions with RAG that admits ignorance below a relevance floor — all on Gemini 2.5 Flash, streamed to the app over SSE, with every admin action written to an audit log."*

---

# PART 5 — LIKELY JURY QUESTIONS & ANSWERS

### Flutter — state, navigation, localization

**Q1. How do you manage state in Flutter?**
Four native mechanisms, each scoped: (1) singleton services exposing a `ValueNotifier` consumed by `ValueListenableBuilder` at the `MaterialApp` root for global reactive state (theme, language); (2) `StatefulWidget`+`setState` for local screen state; (3) a `ChangeNotifier` controller for the AVA chat session; (4) `FutureBuilder` for one-shot async loads. No Provider/BLoC/Riverpod. Files: [theme_service.dart](DHC_transport/lib/core/services/theme_service.dart), [main.dart](DHC_transport/lib/main.dart), [assistant_controller.dart](DHC_transport/lib/screens/assistant/assistant_controller.dart).

**Q2. Why no Provider/Riverpod/BLoC?**
The app has a small, well-bounded set of global state (theme + language) that `ValueNotifier`/`ValueListenableBuilder` handle with zero dependencies and full type safety. Adding a DI/state framework would be over-engineering for two global notifiers, and it would add a learning/maintenance cost with no benefit at this scale. If the app grew (shared cross-screen mutable state, complex derived state), I'd introduce Riverpod — and I can point to exactly where (`AuthService` becoming reactive would be the first candidate).

**Q3. What navigation pattern, and why not GoRouter?**
Navigator 1.0 named routes via a central `onGenerateRoute` factory ([app_router.dart](DHC_transport/lib/core/routing/app_router.dart)) plus imperative `push` for detail screens; tabs use `IndexedStack`+`setState`, not routes, so tab state persists. No deep-linking or web-URL requirements justified GoRouter/Navigator 2.0; the named-route table is the standard dependency-free approach.

**Q4. How does localization work technically?**
A custom key/value dictionary: `LanguageService.t(key,{args})` looks up a hardcoded `{en,fr}` `Map` with English fallback and `{token}` interpolation ([language_service.dart](DHC_transport/lib/core/services/language_service.dart)). `flutter_localizations` only localizes the native Material date/time pickers; `intl` only formats dates. Switching flips a `ValueNotifier` that rebuilds the app. Trade-off vs ARB/gen-l10n: simpler, no codegen, but no ICU pluralization and no compile-time key checking.

**Q5. Why Flutter over React Native / native / PWA / Next.js?**
One Dart codebase → true-native Android/iOS for **both** client and admin apps; embeds the native Google Maps SDK and microphone (voice AVA) that a PWA can't; paints a fully custom luxury design system identically via Skia/Impeller (harder in RN's bridged widgets); Next.js targets browsers, not app stores. Native twice would be 4 codebases.

**Q6. Widget architecture / how are screens composed?**
Shell + `IndexedStack` for tabbed apps ([client_shell.dart](DHC_transport/lib/screens/client/client_shell.dart), [admin_shell.dart](DHC_transport/lib/features/admin/presentation/admin_shell.dart)); many small private widget classes compose each screen; a shared design-system library (`PremiumGlassPanel`, `LuxuryCard`, `PremiumClientNav`, custom `CustomPainter`s). Custom glassmorphic bottom nav, not the stock `NavigationBar`.

### Technology choices

**Q7. Why FastAPI for the backend?**
Async-native (Motor async Mongo + streaming SSE for AVA), Pydantic validation for free, automatic OpenAPI docs, and it's Python — the same language as the LangGraph/LangChain AI stack, so the AI tools call the same service functions as the REST routes with **no HTTP round-trip** ([tools_client.py](backend/app/ai/tools_client.py) imports `booking_service` directly).

**Q8. Why MongoDB over PostgreSQL?**
Flexible nested/evolving documents with no migrations: embedded per-vehicle `pricing`, a singleton `pricing_rules` config doc with nested surcharge objects, bookings that gained fields over time, and heterogeneous `audit_log` shapes. Human-readable string ids. Trade-off: no ACID multi-doc transactions and no joins — acceptable because writes are single-document and relationships are simple FKs resolved in code.

**Q9. Why Google Gemini 2.5 Flash for AVA?**
Fast + cheap + strong tool-calling and instruction-following at `temperature=0` (deterministic classification and exact-value synthesis), with a generous free tier for a PFE. It's wired through `invoke_with_fallback` so a second provider could be added ([model_router.py](backend/app/ai/model_router.py)) — though today the fallback tier is `None` (honest limitation).

**Q10. Why LangGraph instead of a single prompt / plain function-calling?**
The supervisor pattern gives explicit, testable control flow: role-gating, per-domain memory threads, a deterministic safety node, and a confirmation gate — all as graph nodes I can reason about and audit, rather than hoping one big prompt behaves. Each sub-agent is its own small graph (the booking agent even has a no-LLM disambiguation node that saves quota).

### Security

**Q11. How is authentication/authorization handled?**
JWT (HS256, 7-day) issued on login/signup, hashed passwords via passlib **pbkdf2_sha256** ([security.py](backend/app/core/security.py)). Every route declares access via a dependency (`get_current_user`/`require_client`/`require_admin`, [deps.py](backend/app/core/deps.py)); ownership is re-checked in handlers. The client attaches `Authorization: Bearer` on every request ([transport_api_client.dart](DHC_transport/lib/core/services/transport_api_client.dart)).

**Q12. How do you stop the AI from acting on the wrong user or hallucinating actions?**
Defense in depth: role gate (blocks + audit-logs cross-role access), **identity binding** (the LLM's tool schema has no `user_id` — it's injected server-side, so it can't target another user), ownership re-checks in tools, a **confirmation gate** (no write without explicit "yes"), a **safety-check node** (success claims must be backed by a real tool result or they're overridden + logged), and a persona rule forbidding facts not in the retrieved KB. See [tool_registry.py](backend/app/ai/tool_registry.py) + [supervisor.py](backend/app/ai/supervisor.py) + [shared.py](backend/app/ai/agents/shared.py).

**Q13. What are the known security weaknesses (and fixes)?**
Be upfront: (a) the **Google Maps API key is hardcoded in committed Flutter source** ([maps_config.dart](DHC_transport/lib/core/constants/maps_config.dart)) — fix: restrict the key by app signature + API, and proxy Places/Directions through the backend which already holds a key. (b) The **JWT is stored in plain `SharedPreferences`** — fix: `flutter_secure_storage` (Keystore/Keychain). (c) **7-day tokens, no refresh/rotation** — fix: short access token + refresh token. (d) **CORS `allow_credentials=True` with a configurable origin list** — keep it tight in prod.

### Performance

**Q14. What performance optimizations exist?**
Client: 400 ms **debounce** on Places autocomplete ([booking_search_screen.dart](DHC_transport/lib/screens/booking_search_screen.dart)); `IndexedStack` keeps tabs warm; skeleton loaders instead of spinners; `const` widgets throughout; `FallbackNetworkImage` caching. Backend: MongoDB **compound indexes** on hot paths ([indexes.py](backend/app/db/indexes.py)); **one Directions call** prices the whole fleet ([bookings.py](backend/app/api/v1/endpoints/bookings.py) `price-estimate`); sub-agents & the supervisor are **singletons/lazy-cached**; the booking agent's disambiguation is **pure Python (no LLM)** to save quota/latency; RAG embeddings are local (MiniLM) so no per-query embedding API cost.

**Q15. Why SSE and not WebSockets for AVA?**
The chat is one-directional server→client streaming of a single response; SSE is simpler (plain HTTP, works through the existing `http` client + JWT header), auto-reconnect-friendly, and needs no extra protocol. WebSockets would be over-kill for request→streamed-response.

**Q16. Is AVA really streaming token-by-token?**
No — honest answer: streaming is **node-level + keep-alive**, not token-level (the sub-agents call `.ainvoke`, not `.astream_events`). The backend emits one event per graph node and a keep-alive tick, then the full text at `done`; the Flutter bubble does a **client-side typewriter animation** to look streamed ([assistant.py](backend/app/api/v1/endpoints/assistant.py) docstring + [assistant_message_bubble.dart]). True token streaming would require refactoring all six sub-agents.

### AI architecture

**Q17. Walk me through one AVA request end-to-end.**
Flutter `AssistantApiService.chat()` POSTs `{message, thread_id}` with the JWT to `/assistant/chat` → `assistant.py` runs the supervisor in a background task, streaming SSE with keep-alives → `classify` (Gemini or keyword) → `role_gate` → `dispatch` to the domain sub-agent (tools with bound identity, confirmation gate for writes) → `safety_check` → `session_write` → the final text streams as `done` (analytics as a prior event). The controller parses the text into a card and renders it.

**Q18. How does the confirmation gate work, exactly?**
First turn: the LLM proposes a tool call; instead of executing, AVA replies "I'd like to … Reply **yes** to confirm or **no** to cancel" and stores `pending_action`. Next turn: "yes" executes the stored tool and returns a humanized "Done —…"; "no" cancels; anything else re-asks without another LLM call. Implemented in `run_with_confirmation` ([shared.py](backend/app/ai/agents/shared.py)); the supervisor's sticky-confirmation rule keeps the domain stable across the yes/no.

**Q19. How does RAG avoid making things up?**
`search_knowledge_base` returns only chunks scoring **≥ 0.25**; if none clear the floor it returns an **empty list**, and the persona's rule 5 forces AVA to say "I don't have that specific detail" rather than paraphrase a weak chunk. A 0.50 confidence threshold triggers query expansion for vocabulary mismatches. Thresholds were tuned from an observed-score audit ([tools_client.py](backend/app/ai/tools_client.py)). A startup **staleness guard** warns if the index is out of date.

**Q20. How is the price computed and why can't the AI fake it?**
The `create_booking` tool never accepts a price — it calls `_compute_price` server-side (base from the car + surcharges from `pricing_rules` + validated promo). The real quote endpoint (`/bookings/price-estimate`) uses the distance-based Chauffeur formula with Google Directions and a haversine fallback ([pricing_calculator.py](backend/app/services/pricing_calculator.py)). The LLM only reads numbers back, never invents them.

**Q21. What are the analytics capabilities?**
Six deterministic aggregations ([analytics_service.py](backend/app/services/analytics_service.py)): revenue-by-month, revenue-by-category, weekly volume, seasonal peaks + YoY, pricing-impact (before/after a price change), and a KPI summary (MTD/YTD, MoM/YoY, top route/vehicle). `run_business_analysis` turns them into chart specs + KPI tiles + a Gemini analyst narrative, degrading to deterministic insights if the model is unavailable.

### Database & design

**Q22. How do collections relate without joins?**
String foreign keys (`bookings.user_id → users._id`, etc.) resolved in application code; the singleton `pricing_rules {_id:"active"}`; embedded sub-documents (`cars.pricing`) instead of a join. 16 collections are actively used ([indexes.py](backend/app/db/indexes.py) + grep of `db.<name>`); a few more are modelled in `documents.py` but not wired — an honest note about legacy from the original ride-hailing schema.

**Q23. Why string ids instead of ObjectId?**
Human-readable, self-describing, stable across seed/rebuild (`car-comfort-sedan`, `booking-<uuid>`), which made development and debugging easier. Trade-off: slightly larger keys and I manage uniqueness myself (unique indexes on `email`/`code`).

### What I'd improve / add

**Q24. If you had more time, what would you change?**
(1) Proxy Google Maps calls through the backend and remove the hardcoded key; (2) `flutter_secure_storage` for the JWT + a refresh-token flow; (3) unify the **status vocabulary** across DTOs/service/Flutter (currently three variants); (4) collapse the dual theming system (`AppColors` global + `ThemeData`) into a single `ThemeExtension`; (5) real card payment (currently a placeholder); (6) true token-level AVA streaming; (7) real OS push notifications (today they're polled in-app); (8) fix the operations-agent read-only-through-the-confirmation-gate TODO; (9) migrate localization to gen-l10n if a 3rd language is added; (10) add a real second LLM fallback tier.

**Q25. What was the hardest technical problem, and how did you solve it?**
The AVA persona/hallucination problem: early on the model leaked tool names and JSON, claimed actions it hadn't done, and invented vehicle names/policies. I solved it with layered controls — a strict persona prompt, a deterministic safety-check node that overrides unbacked success claims, a RAG relevance floor that forces "I don't know", server-side price computation, and a confirmation gate — every one visible in the code and backed by an `audit_log`.

---

## Appendix — the "gotcha" facts examiners love (all code-verified)

- **Default theme is dark**, default language is **English**, both persisted in `SharedPreferences`.
- The app is branded **Carthage Transfer** but the package is still `dhc_transport` (legacy).
- **Currency is EUR** everywhere (pricing mirrors the real carthage-transfer.com site).
- AVA runs **in-process** with FastAPI — the AI tools import the same service functions as the REST routes (no internal HTTP).
- Embedding model is **local** (`all-MiniLM-L6-v2`) — no embedding API cost; only Gemini is a paid call.
- `temperature=0` for **all** Gemini calls (determinism).
- Every **admin** AI action is written to `audit_log`; so are role denials and safety overrides.
- Contradictions to own before the jury: `config.py` "does not consume maps_api_key" (it does, in pricing); `assistantParsed` "not wired yet" (it is); "two-tier fallback" (fallback tier is `None`); "17 collections" (16 are actually used).
