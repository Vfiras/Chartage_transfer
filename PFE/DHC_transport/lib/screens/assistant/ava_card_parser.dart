/// Parses AVA's plain-text replies into structured card payloads.
///
/// Recognises the three deterministic backend phrasings:
///   • confirmation gate — "I'd like to … Reply **yes** to confirm or **no** to cancel"
///   • disambiguation    — a numbered list ("  1. …\n  2. …") + "reply with the number"
///   • result            — "Done — …" / "I wasn't able to …"
/// Anything with **bold** runs but no card shape → `info`. Everything else, and
/// anything that throws, falls back to `plain` so we never show a broken or
/// half-empty card.
library;

import 'ava_card_data.dart';

class AvaCardParser {
  /// Numbered-list line: "  1. Tunis → Hammamet — Jun 26 · 10:00"
  static final RegExp _numbered =
      RegExp(r'^[ \t]*(\d+)[.)]\s+(.+)$', multiLine: true);

  /// The confirmation-gate instruction sentence. We require the **markdown**
  /// bold the backend always emits ("Reply **yes** to confirm …") so a plain
  /// sentence that merely mentions "reply yes to confirm" stays a plain bubble.
  static final RegExp _confirmInstruction = RegExp(
    r'(?:please\s+)?reply\s+\*\*yes\*\*\s+to\s+confirm(?:\s+or\s+\*\*no\*\*\s+to\s+cancel)?\.?',
    caseSensitive: false,
  );
  static final RegExp _confirmDetect =
      RegExp(r'reply\s+\*\*yes\*\*\s+to\s+confirm', caseSensitive: false);

  static AvaParseResult parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return AvaParseResult.plain;
    try {
      return _tryResult(text) ??
          _tryConfirmation(text) ??
          _trySelection(text) ??
          _tryInfo(text) ??
          AvaParseResult.plain;
    } catch (_) {
      // Any unexpected shape → safe plain text. A card must never crash chat.
      return AvaParseResult.plain;
    }
  }

  // ── Result: "Done — …" / "I wasn't able to …" ────────────────────────────────
  static AvaParseResult? _tryResult(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith("i wasn't able to") ||
        lower.startsWith('i was not able to') ||
        lower.startsWith('i apologize — something went wrong') ||
        lower.startsWith('i apologise — something went wrong')) {
      return AvaParseResult(
        AvaCardType.result,
        ResultCardData(status: AvaResultStatus.failed, headline: _stripMd(text)),
      );
    }
    final done = RegExp(r'^done\s*[—\-:]\s*(.+)', caseSensitive: false, dotAll: true)
        .firstMatch(text);
    if (done != null) {
      final body = _capitalize(_firstSentence(_stripMd(done.group(1)!.trim())));
      final status = RegExp(r'cancel', caseSensitive: false).hasMatch(body)
          ? AvaResultStatus.cancelled
          : AvaResultStatus.success;
      return AvaParseResult(
        AvaCardType.result,
        ResultCardData(status: status, headline: body),
      );
    }
    return null;
  }

  // ── Confirmation: action sentence + "Reply yes to confirm" ───────────────────
  static AvaParseResult? _tryConfirmation(String text) {
    if (!_confirmDetect.hasMatch(text)) return null;

    // Strip the instruction sentence; what remains is the action description.
    var action = text.replaceAll(_confirmInstruction, ' ');
    action = _stripMd(action).replaceAll(RegExp(r'\s+'), ' ').trim();
    // Trim a trailing orphan "or" or "Please" left by partial instructions.
    action = action.replaceAll(RegExp(r'\b(or|please)\s*$', caseSensitive: false), '').trim();
    if (action.isEmpty) action = 'Please confirm this action.';

    // Best-effort structured rows. If extraction misses, the header still
    // carries the full action text — so no information is lost, just no rows.
    final details = <AvaDetailRow>[];
    final route = RegExp(
      r'from\s+(.+?)\s+to\s+(.+?)(?:\s+on\b|\s+at\b|[.,]|$)',
      caseSensitive: false,
    ).firstMatch(action);
    if (route != null) {
      details.add(AvaDetailRow(
        'Route',
        '${route.group(1)!.trim()} → ${route.group(2)!.trim()}',
      ));
    }
    final when = RegExp(r'\bon\s+(.+?)(?:[.]|$)', caseSensitive: false).firstMatch(action);
    if (when != null) {
      details.add(AvaDetailRow('When', _capitalize(when.group(1)!.trim())));
    }

    // A tighter header when we have a route (keep the verb, drop the long tail).
    var header = action;
    if (route != null) {
      final verb = RegExp(r"^(i'?d like to\s+)?(\w+)", caseSensitive: false)
          .firstMatch(action)
          ?.group(2);
      if (verb != null) {
        header = '${_capitalize(verb)} this trip';
      }
    }

    return AvaParseResult(
      AvaCardType.confirmation,
      ConfirmationCardData(actionLabel: header, details: details),
    );
  }

  // ── Selection: numbered disambiguation list (≥2 options) ─────────────────────
  static AvaParseResult? _trySelection(String text) {
    final matches = _numbered.allMatches(text).toList();
    if (matches.length < 2) return null; // 0–1 options is not a selection card

    final options = <AvaSelectionOption>[];
    for (final m in matches) {
      final number = m.group(1)!;
      final body = _stripMd(m.group(2)!.trim());
      if (body.isEmpty) continue;

      var title = body;
      var subtitle = '';
      var sep = body.indexOf(' — ');
      if (sep == -1) sep = body.indexOf(' - ');
      if (sep != -1) {
        title = body.substring(0, sep).trim();
        subtitle = body.substring(sep + 3).trim();
      }
      options.add(AvaSelectionOption(
        title: title.isEmpty ? body : title,
        subtitle: subtitle,
        sendText: number, // backend resolve_selection matches the ordinal digit
      ));
    }
    if (options.length < 2) return null; // re-check after filtering blanks

    var prompt = _stripMd(text.substring(0, matches.first.start))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (prompt.isEmpty) prompt = 'Which one would you like?';

    return AvaParseResult(
      AvaCardType.selection,
      SelectionCardData(prompt: prompt, options: options),
    );
  }

  // ── Info: plain prose that contains **bold** key facts ───────────────────────
  static AvaParseResult? _tryInfo(String text) {
    if (text.contains('**')) {
      return const AvaParseResult(AvaCardType.info, InfoCardData());
    }
    return null;
  }

  // ── helpers ──────────────────────────────────────────────────────────────────
  static String _stripMd(String s) => s.replaceAll('**', '');

  static String _firstSentence(String s) {
    final i = s.indexOf('. ');
    return i == -1 ? s : s.substring(0, i + 1);
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
