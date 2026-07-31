# Carthage Transfer — Design Audit

Auditor lens: Rolls-Royce app / NetJets / Four Seasons digital. The brand system
(near-black `#0B0B0D`–`#1C1C1F`, gold `#C8A96B`, Montserrat, glass cards) is
strong and stays. What follows is where the execution drifts from that standard.

---

## Screen-by-screen findings

### assistant_screen.dart (client AVA) — high traffic
- **Works:** the hero (avatar + LIVE badge + concierge credential chip) is genuinely premium; the input bar (mic / pill / gold send) is the best composed control cluster in the app; quick-action grid is clean.
- **Generic/unfinished:** the top-bar bell button does nothing (`onTap: () {}`) — a dead control on the flagship screen; "View All" next to *Quick Actions* is a gold label with no handler — decorative gold pretending to be interactive, which is exactly what devalues gold.
- **High-impact fix:** remove both dead affordances; give AVA's answer bubbles a gold left accent so her voice is visually "concierge", not "chatbot" (Tier 2).

### booking_fleet_screen.dart (vehicle selection) — revenue screen
- **Works:** real product cards already (badge, image plate, specs, price, select pill); live EUR quotes with the one-way/return toggle; route metrics line.
- **Generic:** full-screen `CircularProgressIndicator` while the fleet + quote load — the single worst "cheap" moment in the buy flow; feature specs are text-only ("4 Pax / 4 Bags") with a hardcoded fake "Free WiFi" on index 0; "FIXED RATE" microcopy under prices regardless of quote type.
- **High-impact fix:** skeleton cards shaped like the real vehicle cards while loading (Tier 1) + product-card hierarchy pass: category kicker, name hero, real feature icons, confident price close (Tier 2).

### booking_success_screen.dart — the emotional peak
- **Works:** structure is right (check → title → receipt card → CTAs); pending-approval variant is honest.
- **Generic:** it reads as a form-submission receipt, not a first-class ticket. `elasticOut` bounce on the check violates "motion felt, not seen". **Bug-level inconsistency: the total says `TND` while the entire quote flow charges EUR.** w900 used on ~9 elements — nothing left to be the hero. Gold on every row icon + ID + chip + total + CTA = gold means nothing here.
- **High-impact fix:** Tier 2 redesign as a boarding-pass ticket (airport-style route codes, perforated divider, vehicle presence, restrained gold), EUR currency, calm check animation.

### booking_confirmation_screen.dart
- **Works:** live route map with the real polyline; clear details card; avatar personalisation.
- **Generic:** "Confirm Booking" title is 26/w900 competing with the map and card; CTA button is a hand-rolled Container that doesn't match any other CTA.
- **High-impact fix:** standardize CTA metrics; let the map + route be the hero, quiet the title (Tier 1).

### contact_confirmation_screen.dart / payment_method_screen.dart
- **Works:** payment screen's two-option layout with badges is exactly the right pattern; 52px CTAs already.
- **Generic:** contact screen's continue CTA differs in metrics from the payment sheet CTA.
- **High-impact fix:** one CTA spec everywhere (Tier 1).

### vehicles_screen.dart (fleet showcase, static)
- **Works:** "EXECUTIVE SELECTION / Premium Fleet" kicker+hero pairing is the typographic model the rest of the app should copy; filter chips with gold selected state are right.
- **Generic:** *four* gold elements compete (header wordmark 28px, kicker, category label, price); header uses a `menu` icon that actually pops the screen — a lie of affordance; prices are stale static "per hour TND" while the booking flow quotes real EUR.
- **High-impact fix:** demote the header wordmark and category label out of gold; back-arrow for back (Tier 1).

### destinations_screen.dart
- **Works:** compact route cards with imagery.
- **Generic/broken:** the filter chips set state but **the list is never filtered** (`const routes = …` ignores `filter`); selected chip is `AppColors.primary` (near-black) — invisible-ish on dark and off-system (selected = gold everywhere else); hardcoded `#888888` greys; cramped 10–12px paddings; prices in TND.
- **High-impact fix:** make the filter actually filter + gold selected chip + token greys (Tier 1/2 boundary; the filter is function-first so it goes in).

### services_screen.dart
- **Works:** simple, scannable service cards.
- **Generic:** "POPULAR" chip uses amber `#FFB400` — off-brand against `#C8A96B`; hardcoded `#777777` copy grey; 24px radius while sibling cards use 20–22.
- **High-impact fix:** brand-token pass (Tier 1).

### client_shell.dart — home / trips / favorites / alerts / profile (highest traffic)
- **Works:** home hero photograph + gradient is the strongest brand moment in the app; trips cards with modify/cancel; favorites/alerts perfectly serviceable; rewards screen already has a tier card + progress bar.
- **Generic:** trips prices hardcode `TND`; profile buries tier/points behind a "Rewards" action row — the client is never *shown* they're a valued member; w900 appears on labels as small as 10px; loading = spinners.
- **High-impact fix:** membership card on profile surfacing tier + points + progress (Tier 2); currency + weight pass (Tier 1).

### AVA chat widgets (user_message_bubble, assistant_message_bubble, typing_indicator)
- **Works:** typewriter streaming with blinking gold cursor; typing dots are subtle; user bubble gold-tint + avatar reads confident; error bubble is genuinely well designed.
- **Generic:** AVA's bubble is the same grey as any chatbot — nothing marks her voice as the concierge; "thinking" (dots) carries no reassurance copy on long dispatches (~10s+).
- **High-impact fix:** gold left-accent on AVA bubbles + "AVA is preparing your answer" microcopy under the dots (Tier 2). *(AVA structured cards themselves are out of scope per brief.)*

### Admin screens (dashboard, bookings, cars, pricing, complaints, promotions, admin AVA)
- **Works:** consistent AppColors usage; new pricing/complaints/pending-approvals sections follow one idiom; AnalyticsCard is on-system.
- **Generic:** every list loads behind a spinner.
- **High-impact fix:** shared skeleton loader (Tier 1). Lower priority than client surfaces (admin ≠ paying customer).

---

## Cross-cutting systems findings

1. **Weight inflation.** `w900` appears on 10px microlabels, body values, buttons, and titles alike. When everything shouts, nothing does. Target scale: **800 hero numbers/names · 700 headings · 600 emphasis/labels · 400–500 body**.
2. **Gold discipline.** Gold currently paints: dead labels, every receipt row icon, category microlabels, wordmarks, status chips, prices, CTAs. Rule enforced in this pass: **gold = interactive or "the one number/status that matters"**; informational icons and decorative kickers become `white60`/tokens.
3. **Currency schism.** Quote flow: EUR (real engine). Receipt/trips/destinations/vehicles: TND. A luxury brand does not change currency between the price and the receipt. Unify user-facing booking surfaces on the quote currency (EUR).
4. **Three parallel token systems** (`AppColors`, `PremiumClientPalette/Theme`, `PremiumProfilePalette` + per-file consts). Values mostly agree, drift shows at seams (ambers, #888 greys, radius 13/14/16/18/20/22/24/28/32). Full unification is Tier 3 (structural); this pass fixes the off-system *values* only.
5. **CTA anarchy.** Primary CTAs found at: vertical-17 Container (success ×2, confirmation), 52px ElevatedButton (payment), PremiumPrimaryButton, PremiumProfilePrimaryButton, LuxuryButton, 44px select pill. Spec going forward: **52px height · radius 14 · gold fill · w800 label, 15px**.
6. **Loading/empty states.** Raw `CircularProgressIndicator` on: fleet selection, trips (initial), favorites, admin lists. Notifications already has a real empty-state widget (good model). Add a shared `LuxurySkeleton` and card-shaped placeholders for the customer-facing lists first.
7. **Icons.** Single set ✓ (Material rounded throughout — no mixed sets found). Sizes drift (13/14/15/18/20/22/24): normalize to **14 chip · 18 row/detail · 20 control · 24 top-bar**.

---

## Prioritized plan

### Tier 1 — Quick wins (pre-approved; implementing after this audit)
| # | Change | Screens | Impact |
|---|--------|---------|--------|
| 1 | Currency: receipts/trips display the quote currency (EUR), never hardcoded TND | booking_success, client_shell trips | Trust — price and receipt finally agree |
| 2 | Remove dead gold affordances (bell `onTap:(){}`, "View All"); vehicles header `menu`→back arrow | assistant_screen, vehicles_screen | Gold regains meaning; no false affordances |
| 3 | Typography de-shout: w900→w800 max (heroes only), microlabels→w700, one visual entry point per screen (demote competing heads) | success, vehicles, services, client_shell, confirmation | Hierarchy without noise |
| 4 | Gold discipline: receipt row icons→white60, vehicles wordmark/category label→neutral, services POPULAR amber→gold token, destinations selected chip→gold | success, vehicles, services, destinations | Gold = important again |
| 5 | CTA standard 52px/r14/gold/w800: success ×2, confirmation confirm, contact continue | 4 screens | One-brand buttons |
| 6 | `LuxurySkeleton` shared shimmer + card skeletons replace spinners; real empty state for fleet | fleet (priority), trips, admin bookings/complaints/pricing | Loading feels designed |
| 7 | Token greys replace #777/#888; radius drift 24→20 on services cards; destinations card breathing room (padding 12→16, image 100→112) | services, destinations | Consistency at the seams |
| 8 | Destinations filter actually filters (function-first fix, 3 lines) | destinations | Broken control now works |

### Tier 2 — Component upgrades
| # | Component | Direction |
|---|-----------|-----------|
| 1 | **Booking success → first-class ticket** | Airport-style route codes (TUN → HAM derived from location names), perforated ticket divider with edge notches, vehicle presence on the ticket, calm gold check (ease-out draw + soft glow, no elastic bounce), restrained gold (ID + total + CTA only) |
| 2 | **Vehicle selection cards** | Category kicker above name-as-hero, real feature icon row (AC · free waiting · capacity) replacing fake WiFi, price block as the confident close ("from" microcopy + currency), image plate refined |
| 3 | **AVA bubbles** | 2px gold left accent + slightly warmed surface on AVA bubbles; typing indicator gains "AVA is preparing your answer…" microcopy; thinking vs answered becomes unmistakable |
| 4 | **Profile membership card** | Tier + points + progress-to-next-tier as a gold-on-black membership card directly on the profile (data from existing RewardService), replacing the buried text row |
| 5 | *(from audit)* Destinations cards | Gold chip states, tokened greys, generous padding — folded into Tier 1 items 4/7/8 |

### Tier 3 — Screen-level redesigns: **deliberately none this pass**
- *Token-system unification* (3 palettes → 1) is the real structural debt, but it touches every screen incl. finalized ones (bottom nav, search map) — risk exceeds reward in this pass.
- *Destinations screen* layout is dated but low-traffic; its worst sins are fixed in Tier 1.
- Home, trips, profile layouts are structurally sound — they need the polish above, not new bones.

### Explicitly untouched (per brief)
Gold/dark/Montserrat system · navigation flows & data wiring · bottom nav · AVA structured cards (confirmation/selection/result/info) · booking search map screen · all backend code.
