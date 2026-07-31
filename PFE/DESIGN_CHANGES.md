# Design Changes Log — Carthage Transfer elevation pass

Companion to `DESIGN_AUDIT.md`. Every change below, with why it's more premium.
Constraints honored: gold/dark/Montserrat untouched as a system · no nav/data
changes · bottom nav untouched · AVA structured cards untouched · search-map
screen untouched · zero backend changes. `flutter analyze`: **No issues found.**

---

## New shared primitives

**`widgets/common/luxury_cta.dart` — `LuxuryCta`**
One primary-CTA spec: 52px · radius 14 · gold fill · w800/15 label · ink text;
`outlined:` variant for secondary actions; built-in loading state.
*Why premium: a luxury brand never surprises you with a different button.*

**`widgets/common/luxury_skeleton.dart` — `SkeletonPulse / SkeletonBox / SkeletonCardList / SkeletonVehicleCards`**
Ease-out shimmer placeholders shaped like the content they replace.
*Why premium: a spinner says "computer working"; a skeleton says "your content is arriving".*

---

## Screen by screen

### booking_success_screen.dart — full Tier 2 rewrite ("first-class ticket")
- Route rendered as airport-style codes (TUN → HAM, derived from real Tunisian airports/cities) with a car glyph on the route line; full place names as microcopy. *A ticket, not a database row.*
- Perforated ticket fold (edge notches + dotted rule) between the travel half and the fare half. *The universal boarding-pass cue.*
- Vehicle present on its white plate with the model name beneath. *You see what you bought.*
- Gold check now **draws itself** (CustomPainter, 650ms ease-out sequence) — replaced the `elasticOut` bounce. *Motion felt, not seen.*
- **Total now shows the quote currency (EUR)** — was hardcoded TND against an EUR quote. *The receipt agrees with the price.*
- Gold reduced to: check, status chip, total, CTA. Row icons and labels are quiet white. *Gold means something again.*
- Both CTAs → `LuxuryCta` (primary + outlined). w900s removed.
- Pending-approval variant kept: status chip reads PENDING APPROVAL, quiet notification note under the ticket.

### booking_fleet_screen.dart (vehicle selection)
- Loading: full-screen spinner → header/summary/toggle stay put + `SkeletonVehicleCards` where the products will appear. *The shop never disappears.*
- Empty state added (fleet API down): icon + copy + retry. *No blank walls.*
- Product card hierarchy: vehicle **name is the hero** (19/w800), model demoted, duplicate model line suppressed.
- Fake "Free WiFi" chip removed → real "1h Wait" (every transfer includes 1h free waiting — an actual selling point).
- Price block: 19/w800 gold + honest microcopy — **ALL-INCLUSIVE** for a real routed quote, **ESTIMATED** for the offline fallback (was always "FIXED RATE"). *Confidence built on truth.*
- Image on a rounded, padded plate; Select pill label w500→w700.

### assistant_screen.dart (client AVA)
- Dead bell button (`onTap: (){}`) removed — replaced by a spacer so the wordmark stays centred. *Nothing on a luxury screen pretends to work.*
- Dead gold "View All" label removed from Quick Actions.

### assistant/widgets/assistant_message_bubble.dart
- AVA's answers carry a slim gold accent bar along their left edge (outside the rounded bubble — a one-sided gold border on a rounded box is a Flutter paint assertion). Error bubbles keep their own red identity. *Her voice reads concierge, not chatbot.*

### assistant/widgets/typing_indicator.dart
- "AVA is preparing your answer…" microcopy (quiet italic, no gold) beside the dots. *Long dispatches feel attended, not hung.*

### booking_confirmation_screen.dart
- Confirm button → `LuxuryCta` (was a hand-rolled 17px-padding container).
- "Confirm Booking" title 26/w900 → 22/w800: the live route map and receipt card are the heroes. All w900 → w800.

### contact_confirmation_screen.dart
- Continue button → `LuxuryCta`. w900 → w800.

### payment_method_screen.dart
- "Continue with Cash" sheet button → `LuxuryCta` (identical CTA everywhere).

### vehicles_screen.dart (fleet showcase)
- Header: `menu` icon that actually popped the screen → `arrow_back` (an honest affordance); "Carthage Transfer" 28px gold wordmark → quiet 12px letterspaced caps. *"Premium Fleet" is now this screen's single hero.*
- Category microlabel (BUSINESS CLASS…) gold/w900 → white-60/w700: informational, not important. *Gold stays on the price.*

### destinations_screen.dart
- **Filter chips now actually filter** (matched on either route endpoint) — the control was decorative before.
- Selected chip: near-black `AppColors.primary` → gold with ink text, 160ms ease-out, matching every other chip in the app.
- Hardcoded `#888888` greys → `AppColors.textMuted` tokens; price now gold w800 (the row's one accent); card padding 12→16, image 100→112, radius 22→20.
- Filtered-empty state added (icon + copy).

### services_screen.dart
- "POPULAR" chip amber `#FFB400` → brand `chipGoldBg`. *One gold in this app.*
- `#777/#888` greys → `textMuted` tokens; card radius 24→20; padding 16→18.

### client_shell.dart (home / trips / favorites / profile / rewards)
- **Trips card price: `TND` → `EUR`** (and fixed-amount promo copy "TND off" → "EUR off"). *Quote and receipt in the same currency.*
- Trips initial load: spinner → 3 trip-card skeletons.
- **New `_MembershipCard` on the profile** (Tier 2): dark-lacquer gradient card with gold detailing — CARTHAGE PRIVILÈGE wordmark, tier chip, points as the hero number, gold progress bar, "N RIDES TO SILVER", member name in caps. Tappable → full Rewards screen (replaces the buried "Rewards" text row). Hidden for guests; renders gracefully while loading. *The client is shown they're a member, not told.*
- All `w900` → `w800` across the file (labels, chips, titles).

### Admin screens (bookings, complaints, pricing)
- List loading: spinners → `SkeletonCardList` shaped like each screen's cards.

### App-wide
- `FontWeight.w900` eliminated everywhere (incl. `app_theme.dart`, `luxury_components.dart`, `booking_card.dart`, `admin_promotions_screen.dart`) → w800 ceiling per the type scale (800 hero / 700 heading / 600 label / 400–500 body).

---

## Tier 3 — none attempted (by design)
The audit's only structural candidate (unifying the three parallel token systems) touches finalized surfaces (bottom nav, search map) for invisible user gain — risk over reward. Logged as future debt in `DESIGN_AUDIT.md`.

## Known trade-offs
- `destinations_screen` prices remain TND: static marketing data, not quote-flow output; flagged rather than silently "converted".
- Trips-card EUR label assumes post-pricing-engine bookings (all quotes are EUR); pre-engine demo seeds display in EUR too — acceptable for the demo dataset.
- Icon set was already single-source (Material rounded); sizes normalized opportunistically in touched code (14 chip / 18 row / 20 control) rather than by exhaustive sweep.
