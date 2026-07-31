# AVA Client Screen — Design Audit (assistant_screen.dart)

Lens: Aman's concierge screen, Amex Centurion chat, Bonvoy Concierge. The shared
DNA of those screens: **quiet confidence, one hero moment, and the sense of a
person waiting for you** — not a feature list with a chat box under it.

Honest verdict on the current screen: the *ingredients* are premium (portrait,
gold, Montserrat, typewriter streaming) but the *composition* is an app template.
It reads "AI chatbot page with a nice avatar," not "your concierge's suite."

---

## The five named problems — confirmed, with specifics

### 1. The portrait floats context-free
The 108px portrait sits directly on `#0B0B0D` with only its own 1.5px ring
(gold @35%). Nothing receives it — no light, no stage, no depth. In real luxury
presentation a concierge is *framed*: the warm pool of light at a hotel desk,
the vignette behind a maître d'. On black, an unframed circular photo reads as
a stock asset dropped onto a canvas. **Fix: a soft radial "backlit stage light"
(gold at ~8% fading to transparent) behind the portrait + a thin gold ring —
light, not ornament.** The LIVE pill also uses a `#22C55E` green dot — the only
green pixel in the entire app; generic "online status" vocabulary from
messenger apps, off-palette here.

### 2. The greeting is the hero, and it shouldn't be
"Good Evening, Demo" is the largest element (26px w700). Two problems:
(a) a greeting is *context*, not a moment — the moment is the invitation to
converse; (b) the home screen hero **already says "Good Evening, {name}"** in
30px — the same line twice in one app cheapens both. Meanwhile the actual
invitation ("Your personal travel concierge, AVA, is here to assist.") is
demoted to 14px grey subtitle. The hierarchy is exactly inverted.

### 3. Quick Actions are admin-panel furniture
A 2×2 `GridView` of dark rounded rectangles with icon-circle + label — the
default pattern of every dashboard template. Specific sins:
- Labels are **feature names with forced line-breaks** ("Modify\nBooking",
  "Track\nRide") — reads like buttons on a settings page, and the `\n` is a
  typographic hack.
- A "Quick Actions" section title labels the furniture — a real concierge menu
  doesn't say "MENU OF THINGS TO SAY".
- The 2.2 aspect-ratio cards are ~74px tall: a 38px icon circle dominating a
  cramped 12px two-line label.
- They sit on a *different visual surface* (bordered cards) than the concierge
  above, so they read as a separate widget zone, not prepared conversation
  starters offered by her.

### 4. Dead vertical space
Fresh-open composition: ~16px + 108px portrait + 20 + greeting + 8 + subtitle +
16 + credential pill + 32 + section title + 14 + 2×74px grid + 32 … the first
message would render at ~60% screen depth, and on cold open roughly a third of
the viewport is empty black between loosely-stacked centered elements. Luxury
space is *composed* generosity (margins around a dense, confident object) —
this is *leftover* space.

### 5. The concierge zone never yields to the conversation
Hero + grid + messages live in one ListView. Consequences:
- The transition to conversation is a scroll position, not a state change.
- Mid-conversation, scrolling up re-reveals the full lounge ("Good Evening…"
  + action grid) *above* the chat history — the lounge becomes an
  archaeological layer under the transcript.
- The action grid stays tappable forever, competing with the conversation it
  was only meant to start.
A concierge steps back once the conversation begins. The screen never does.

---

## Additional findings

6. **Redundant self-introduction ×4.** Wordmark "AVA" (top bar) + "LIVE" pill +
   subtitle "Your personal travel concierge, AVA…" + "Senior Travel Concierge"
   credential pill — four assertions of the same fact on one screen. Confidence
   states things once.
7. **The credential pill is app-store generic.** Icon-in-a-tinted-capsule is the
   vocabulary of feature badges ("✓ Verified"). The luxury treatment of a
   credential is *typographic*: hairline rule + letterspaced caps.
8. **Disabled send button reads broken.** Gold @35% circle with a dark icon at
   35% — looks like a rendering bug rather than a state.
9. **Input field has no focus life.** Same white@10% border focused or not;
   the one control the user must trust with their words gives no acknowledgment
   of attention.
10. **Bubble rhythm is metronomic.** Every bubble carries the same 18px bottom
    gap regardless of sender adjacency — conversations read as a list of
    equal items, not paired exchanges. (Pairs need air ~20px; same-sender
    runs need grouping ~8px.)
11. **Timestamps compete.** 10px at full `#A1A1AA` under every bubble; at 40%
    opacity they'd do the same job from the background.
12. **No empty-state invitation.** Below the grid, silence. A single quiet line
    ("Ask about your trips, our fleet, or anything else.") sets expectations
    without begging.
13. **No arrival moment.** The screen pops in fully-formed. One 200ms entrance
    (fade + 0.96→1.0 scale, single vignette breath), once per session, is the
    difference between "page loaded" and "she's here."

---

## Redesign plan (per brief)

| # | Change | Detail |
|---|--------|--------|
| 1 | Compressed, framed hero | 92px portrait, gold ring @30%, radial gold @8% backdrop; LIVE pill smaller w/ gold dot |
| 2 | Inverted hierarchy | greeting 18px w400 gold@90% → hero invitation "How may I assist you today?" 26px w300 ls0.5 warm white |
| 3 | Typographic credential | hairline gold rule + "SENIOR TRAVEL CONCIERGE · AVAILABLE 24/7" 10px ls3 caps (pill deleted; subtitle deleted) |
| 4 | Concierge menu | single horizontal row of pill chips, gold icon left, **natural first-message labels** ("Change my upcoming trip", "Where's my driver?", "Airport meet-and-greet", "My rewards & benefits"); no section title; tap sends the label itself |
| 5 | Lounge → conversation state machine | zero messages = full lounge; first message = lounge yields entirely, top bar gains mini-portrait + name (250ms ease-out fade-through); chat owns the screen |
| 6 | Entrance moment | once per session: 200ms fade/scale + one vignette breath |
| 7 | Input life | 1px gold border 20% → 60% on focus; gold-tinted send shadow; honest disabled state |
| 8 | Conversation rhythm | 20px between exchange pairs, 8px within same-sender runs; timestamps 10px @40% |
| 9 | Quiet hint | "Ask about your trips, our fleet, or anything else." 12px muted, lounge only |

**Untouched, per brief:** AVA structured cards, SSE/controller/voice wiring,
token system, all other screens. (Bubble widgets receive only a spacing
parameter + timestamp opacity — layout-only, defaults preserve the admin chat.)
