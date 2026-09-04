/// Local intent detection for AVA's interactive cards.
///
/// Runs in the app BEFORE a message is sent. When a message is a vague booking
/// request ("book a trip"), the chat answers it with a form card instead of
/// forwarding it — which is what removes the six-message question-and-answer
/// round trip. The backend is untouched: once the card is filled it sends one
/// complete sentence through the ordinary text flow.
library;

enum AvaIntent { none, booking, modify, cancel }

class AvaIntentDetector {
  /// Matches "from X to Y" and the bare "X to Y" people also type.
  static final RegExp _fromTo = RegExp(
    r'from\s+(?<from>.+?)\s+to\s+(?<to>.+?)(?:$|[.,;!?]|\s+\b(?:on|at|for|with|tomorrow|today|next)\b)',
    caseSensitive: false,
  );

  /// Words that mean an EXISTING trip. Checked first so "change my booking"
  /// never opens the new-booking form.
  static final RegExp _existing = RegExp(
    r'\b(cancel|modify|change|update|reschedule)\b',
    caseSensitive: false,
  );

  static AvaIntent detect(String text) {
    final s = text.toLowerCase();
    if (_isCancel(s)) return AvaIntent.cancel;
    if (_isModify(s)) return AvaIntent.modify;
    if (_isBooking(s)) return AvaIntent.booking;
    return AvaIntent.none;
  }

  static bool _isBooking(String s) {
    if (_existing.hasMatch(s)) return false;
    final booksSomething = s.contains('book') &&
        (s.contains('trip') || s.contains('ride') || s.contains('car') ||
            s.contains('transfer'));
    return booksSomething ||
        s.contains('new trip') ||
        s.contains('new booking') ||
        s.contains('reserve') ||
        s.contains('need a ride');
  }

  static bool _isModify(String s) =>
      s.contains('modify') ||
      s.contains('reschedule') ||
      s.contains('change my trip') ||
      s.contains('change my booking') ||
      s.contains('update my booking') ||
      s.contains('change my upcoming');

  static bool _isCancel(String s) =>
      s.contains('cancel my') ||
      s.contains('cancel booking') ||
      s.contains('cancel a booking') ||
      s.contains('cancel trip') ||
      s.contains('cancel the trip');

  /// Pulls a route out of the sentence so the form opens pre-filled.
  /// Returns (null, null) when the user did not state one.
  static (String?, String?) extractRoute(String text) {
    final m = _fromTo.firstMatch(text);
    if (m == null) return (null, null);
    return (_clean(m.namedGroup('from')), _clean(m.namedGroup('to')));
  }

  static String? _clean(String? raw) {
    if (raw == null) return null;
    // Strip the request verbs that sit in front of the pickup in
    // "I want to book a trip from ...". \b keeps "Carthage" intact.
    var v = raw
        .replaceAll(
            RegExp(
                r'^(i\s+(would\s+like|want|need|wanna)\s+to\s+)?(please\s+)?'
                r'(book|reserve|schedule)?\s*(me\s+)?(a\s+|an\s+|the\s+)?'
                r'(trip|ride|transfer|car|taxi)?\b\s*',
                caseSensitive: false),
            '')
        .trim();
    v = v.replaceAll(RegExp(r'[.,;:!?]+$'), '').trim();
    // Trailing politeness / filler the route regex has no terminator for,
    // e.g. "... to Sousse please".
    v = v
        .replaceAll(
            RegExp(r'\s+\b(please|thanks|thank\s+you|asap|now)\b\.?$',
                caseSensitive: false),
            '')
        .trim();
    if (v.length < 2 || v.length > 80) return null;
    return v;
  }
}
