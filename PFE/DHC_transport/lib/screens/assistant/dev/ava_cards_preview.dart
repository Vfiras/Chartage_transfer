import 'package:flutter/material.dart';

import '../ava_card_data.dart';
import '../ava_card_parser.dart';
import '../widgets/ava_card_tokens.dart';
import '../widgets/confirmation_card.dart';
import '../widgets/result_card.dart';
import '../widgets/selection_card.dart';

/// Dev-only gallery: renders every card from REAL backend phrasings run through
/// AvaCardParser, so this previews the actual parse→card pipeline (not hand-built
/// card data). Not part of the shipped app — launched via lib/dev_preview_main.dart.
class AvaCardsPreviewScreen extends StatelessWidget {
  const AvaCardsPreviewScreen({super.key});

  // Verbatim examples of what the backend sends today.
  static const _confirmRaw =
      "I'd like to cancel your trip from Tunis Airport to Hammamet on June 26 at 10:00. "
      "Reply **yes** to confirm or **no** to cancel.";
  static const _selectionRaw =
      "I found 3 upcoming bookings on your account. Which one would you like to cancel?\n\n"
      "  1. Tunis Airport → Hammamet — Jun 26 at 10:00\n"
      "  2. Tunis City Centre → Sousse — Jun 28 at 14:00\n"
      "  3. Enfidha Airport → Monastir — Jul 02 at 08:30\n\n"
      "Please reply with the number, or describe the trip.";
  static const _resultCancelledRaw = "Done — your booking has been cancelled.";
  static const _resultSuccessRaw =
      "Done — your complaint has been submitted. Our team will review it shortly.";
  static const _resultFailedRaw =
      "I wasn't able to do that — the booking could not be found.";
  static const _infoRaw =
      "You're currently a Bronze-tier member with 10 points. You need **40 more points "
      "(4 more completed trips)** to reach **Silver**.";
  // Unrecognized prose (no card pattern) → must stay a plain bubble.
  static const _plainFallbackRaw =
      "Your driver will meet you in the arrivals hall holding a sign with your name.";
  // Confirm phrasing but NO extractable action → safe 'Please confirm…' header,
  // never a blank card.
  static const _degenerateConfirmRaw =
      "Reply **yes** to confirm or **no** to cancel.";
  // Stress test: a deliberately long route value — does the label/value row hold?
  static const _stressLongRaw =
      "I'd like to cancel your trip from Tunis-Carthage International Airport (TUN), "
      "Arrivals Terminal 1, Meeting Point B to Sousse Medina city centre, Boujaffar "
      "seafront on Thursday, June 26 2026 at 10:00 in the morning. "
      "Reply **yes** to confirm or **no** to cancel.";

  @override
  Widget build(BuildContext context) {
    void fakeSend(String t) => ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('would send: "$t"'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: kAvaSurface,
      ));

    return Scaffold(
      backgroundColor: kAvaBg,
      appBar: AppBar(
        backgroundColor: kAvaBg,
        title: const Text('AVA Cards — Preview',
            style: TextStyle(color: kAvaGold, fontSize: 15, letterSpacing: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          _label('1 · Confirmation (parsed)'),
          _rendered(_confirmRaw, fakeSend),
          _label('2 · Selection / disambiguation (parsed)'),
          _rendered(_selectionRaw, fakeSend),
          _label('3 · Result — cancelled (parsed)'),
          _rendered(_resultCancelledRaw, fakeSend),
          _label('4 · Result — success (parsed)'),
          _rendered(_resultSuccessRaw, fakeSend),
          _label('5 · Result — failed (parsed)'),
          _rendered(_resultFailedRaw, fakeSend),
          _label('6 · Info answer — bold key facts (parsed)'),
          _rendered(_infoRaw, fakeSend),
          _label('7 · Fallback — unrecognized text stays a plain bubble'),
          _rendered(_plainFallbackRaw, fakeSend),
          _label('8 · Edge — confirm phrasing, no action → safe header'),
          _rendered(_degenerateConfirmRaw, fakeSend),
          _label('9 · Stress — long detail value (does the row hold?)'),
          _rendered(_stressLongRaw, fakeSend),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10),
        child: Text(
          t,
          style: const TextStyle(
            color: kAvaTextSec,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );

  /// Mirrors what the live bubble will do in Step 3: parse, then render the
  /// matching card — or a plain bubble if there's no card.
  Widget _rendered(String raw, void Function(String) onSend) {
    final parsed = AvaCardParser.parse(raw);
    switch (parsed.type) {
      case AvaCardType.confirmation:
        return ConfirmationCard(
          data: parsed.data as ConfirmationCardData,
          onRespond: onSend,
        );
      case AvaCardType.selection:
        return SelectionCard(
          data: parsed.data as SelectionCardData,
          onSelect: onSend,
        );
      case AvaCardType.result:
        return ResultCard(data: parsed.data as ResultCardData);
      case AvaCardType.info:
        return _infoBubble(raw);
      case AvaCardType.none:
        return _plainBubble(raw);
    }
  }

  Widget _infoBubble(String raw) => _bubbleShell(
        RichText(
          text: TextSpan(
            children: avaBoldSpans(
              raw,
              const TextStyle(
                color: Color(0xFFE9E1DA),
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );

  Widget _plainBubble(String raw) => _bubbleShell(
        Text(
          raw,
          style: const TextStyle(
            color: kAvaOnSurface,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      );

  Widget _bubbleShell(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: kAvaSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: child,
      );
}
