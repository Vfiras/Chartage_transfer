import 'ava_card_data.dart';
import 'ava_card_parser.dart';

enum MessageRole { user, assistant }

/// Optional rich attachment rendered beneath an assistant message.
enum InlineCard { none, scheduleUpdate }

/// Interactive form cards the app inserts locally (no backend event).
/// They collect a whole booking / modification / cancellation in one card
/// instead of AVA asking for each field in its own turn.
enum AvaInteractiveCard { none, bookingForm, modifyBooking, cancelBooking }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool shouldStream;
  final InlineCard inlineCard;
  final bool isError;

  /// Structured-card classification of this message (none = plain bubble).
  final AvaCardType cardType;

  /// Typed payload for the card, when [cardType] is not none.
  final AvaCardData? cardData;

  /// Business-analysis payload (charts/kpis/insights) from the backend's
  /// "analytics" SSE event. When set, the admin chat renders an AnalyticsCard
  /// instead of a plain bubble; [text] carries the analyst narrative.
  final Map<String, dynamic>? analyticsData;

  /// Which interactive form this message renders, if any.
  final AvaInteractiveCard interactiveCard;

  /// Seed data for that form — pre-filled route, or the bookings to choose
  /// from. Never sent anywhere; consumed by the widget.
  final Map<String, dynamic>? cardSeed;

  bool get fromUser => role == MessageRole.user;
  bool get isAnalytics => analyticsData != null;
  bool get isInteractive => interactiveCard != AvaInteractiveCard.none;

  ChatMessage({
    String? id,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.shouldStream = false,
    this.inlineCard = InlineCard.none,
    this.isError = false,
    this.cardType = AvaCardType.none,
    this.cardData,
    this.analyticsData,
    this.interactiveCard = AvaInteractiveCard.none,
    this.cardSeed,
  })  : id = id ?? _uid(),
        timestamp = timestamp ?? DateTime.now();

  static String _uid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  factory ChatMessage.user(String text) =>
      ChatMessage(text: text, role: MessageRole.user);

  factory ChatMessage.assistant(String text, {bool stream = false}) =>
      ChatMessage(
        text: text,
        role: MessageRole.assistant,
        shouldStream: stream,
      );

  /// Like [assistant], but runs the card parser so the message carries a
  /// structured [cardType]/[cardData]. Not wired into the live flow yet — used
  /// by previews and (after approval) the controller's `done` handler.
  factory ChatMessage.assistantParsed(String text, {bool stream = false}) {
    final parsed = AvaCardParser.parse(text);
    return ChatMessage(
      text: text,
      role: MessageRole.assistant,
      shouldStream: stream,
      cardType: parsed.type,
      cardData: parsed.data,
    );
  }

  factory ChatMessage.error(String text) => ChatMessage(
        text: text,
        role: MessageRole.assistant,
        isError: true,
      );

  /// An interactive form card inserted locally by the app.
  factory ChatMessage.interactive(
    AvaInteractiveCard card, {
    Map<String, dynamic> seed = const {},
  }) =>
      ChatMessage(
        text: '',
        role: MessageRole.assistant,
        interactiveCard: card,
        cardSeed: seed,
      );

  /// Business-analysis response: narrative + chart/KPI payload.
  factory ChatMessage.analytics(String narrative, Map<String, dynamic> data) =>
      ChatMessage(
        text: narrative,
        role: MessageRole.assistant,
        analyticsData: data,
      );

  String get timeLabel {
    final h = timestamp.hour;
    final m = timestamp.minute.toString().padLeft(2, '0');
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }
}
