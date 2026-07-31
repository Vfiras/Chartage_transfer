# AVA Client Screen — Redesign Notes

Companion to `AVA_SCREEN_AUDIT.md`. Reference DNA: Aman concierge, Amex
Centurion chat, Bonvoy Concierge — quiet confidence, one hero moment, a person
waiting for you. Nothing below touches the AVA card system, SSE/controller
wiring, voice input logic, the token system, or any other screen.

---

## The big move: a lounge, then a conversation

**Before:** hero + "Quick Actions" grid + messages all lived in one ListView.
The conversation never *began* — it just appeared below the furniture, and
scrolling up mid-chat re-excavated the greeting and the action grid.

**After:** two explicit states with one deliberate transition.
- **Lounge** (zero messages): the concierge receives you — framed portrait,
  greeting, invitation, credential, prepared conversation starters, a quiet
  hint. Nothing else.
- **Conversation** (first message onward): the lounge yields *entirely*. The
  top bar gains AVA's small portrait beside the wordmark (the concierge steps
  back but stays present), and the transcript owns the full screen.
- The switch is a 250ms ease-out fade (`AnimatedSwitcher`), mirrored in the
  top bar. A state change, not a scroll position.

*Why: a concierge greets you once, then gets out of the way. The room doesn't
keep re-introducing her.*

## The portrait is now framed, not floated

**Before:** 108px photo directly on black; only its own border. Green LIVE dot.
**After:** 92px portrait · thin gold ring @30% · a soft radial "stage light"
(gold 8% → transparent) behind her — light, not ornament. The LIVE pill is
smaller, capsule-shaped, **gold dot** (the app's only green pixel is gone).

*Why: luxury presentation frames people in warm light. The vignette gives her
a place to stand.*

## Hierarchy inverted: the invitation is the hero

**Before:** "Good Evening, Demo" at 26/w700 (also the home screen's hero line —
the same moment spent twice), invitation demoted to a grey 14px subtitle.
**After:** greeting at 18/w400 gold@90 (context) → **"How may I assist you
today?" at 26/w300, letter-spaced, warm white** (the moment) → hairline gold
rule + `SENIOR TRAVEL CONCIERGE · AVAILABLE 24/7` in 10px/ls3 caps (the
credential as typography — the generic icon-pill and the redundant subtitle
are deleted).

*Why: w300 at display size is the typographic voice of service — lighter is
more confident. The credential treatment is how it would appear on stationery,
not on an app-store badge.*

## Quick Actions → prepared conversation starters

**Before:** a 2×2 grid of dark cards titled "Quick Actions", labels like
"Modify\nBooking" (admin-panel vocabulary, forced line breaks).
**After:** one horizontal row of pill chips — small gold icon, natural first
messages, no section title:
- "Change my upcoming trip" · "Where's my driver?" · "Airport meet-and-greet"
  · "My rewards & benefits"
Tapping a chip sends **exactly what it says** (so the user's bubble matches
what they tapped). The half-visible last chip is the scroll affordance.

*Why: these are things you'd say, not features you'd select. They sit on the
concierge's surface, offered by her, and they disappear with the lounge once
the conversation starts.*

## One arrival moment, once per session

200ms fade + 0.96→1.0 scale on the lounge, and the stage light takes a single
breath (8% → 14% → 8%). Implemented with one controller and a session-static
flag — reopening the tab later in the session does not replay it.

*Why: "she's here", stated once. Repeated flourishes become wallpaper.*

## The input acknowledges attention

- Field border: gold **20%** at rest → **60%** in focus (150ms).
- Send button: gold with a soft gold-tinted shadow when enabled; when disabled
  it becomes a quiet outlined circle (the old 35%-gold-with-dark-icon read as
  a rendering bug).
- Mic button and all voice wiring untouched.

## Conversation rhythm

- **20px between exchange pairs, 8px within same-sender runs** (computed per
  message in the screen; the bubble widgets gained an optional `bottomSpacing`
  parameter whose default preserves the admin chat exactly).
- Timestamps muted to 10px @ 40% white — present, no longer competing.
- Empty-state hint under the chips: *"Ask about your trips, our fleet, or
  anything else."* 12px, muted — inviting without begging.

---

## Verification
- `flutter analyze`: No issues found.
- Screenshots (scratchpad + shown in session): (a) lounge fresh open,
  (b) first exchange, (c) longer conversation with the compressed top-bar
  portrait.
- Admin AVA chat verified unaffected (shared bubbles keep default spacing;
  its own screen composition untouched).
