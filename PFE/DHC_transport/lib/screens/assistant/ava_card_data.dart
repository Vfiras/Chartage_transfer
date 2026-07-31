/// Typed payloads for AVA's structured chat cards.
///
/// The backend keeps sending plain-text SSE `done`/`error` events — these types
/// describe how the Flutter side *displays* that text once a parser
/// (ava_card_parser.dart) has recognised a known pattern. Nothing here changes
/// the backend contract.
library;

enum AvaCardType { none, confirmation, selection, result, info }

enum AvaResultStatus { success, cancelled, failed }

/// A label/value line ("Route" → "Tunis Airport → Hammamet").
class AvaDetailRow {
  final String label;
  final String value;
  const AvaDetailRow(this.label, this.value);
}

/// One tappable option in a disambiguation list.
class AvaSelectionOption {
  final String title; // e.g. "Tunis Airport → Hammamet"
  final String subtitle; // e.g. "Jun 26 · 10:00"
  final String sendText; // exact text sent on tap, e.g. "1"
  const AvaSelectionOption({
    required this.title,
    required this.subtitle,
    required this.sendText,
  });
}

/// Base type so ChatMessage can hold any card payload with one field.
abstract class AvaCardData {
  const AvaCardData();
}

class ConfirmationCardData extends AvaCardData {
  final String actionLabel; // header line, e.g. "Cancel your trip to Hammamet"
  final List<AvaDetailRow> details; // optional — may be empty
  final String confirmLabel;
  final String cancelLabel;
  final String confirmSendText; // "yes"
  final String cancelSendText; // "no"

  const ConfirmationCardData({
    required this.actionLabel,
    this.details = const [],
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmSendText = 'yes',
    this.cancelSendText = 'no',
  });
}

class SelectionCardData extends AvaCardData {
  final String prompt; // header question
  final List<AvaSelectionOption> options;
  const SelectionCardData({required this.prompt, required this.options});
}

class ResultCardData extends AvaCardData {
  final AvaResultStatus status;
  final String headline;
  final List<AvaDetailRow> details; // optional
  const ResultCardData({
    required this.status,
    required this.headline,
    this.details = const [],
  });
}

/// Info answers reuse the normal bubble; the only "structure" is that any
/// **bold** runs in the text get rendered as real bold spans.
class InfoCardData extends AvaCardData {
  const InfoCardData();
}

/// Result of parsing one assistant message.
class AvaParseResult {
  final AvaCardType type;
  final AvaCardData? data;
  const AvaParseResult(this.type, this.data);

  /// No card — render as a plain text bubble.
  static const AvaParseResult plain = AvaParseResult(AvaCardType.none, null);
}
