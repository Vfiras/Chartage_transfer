enum MessageRole { user, assistant }

/// Optional rich attachment rendered beneath an assistant message.
enum InlineCard { none, scheduleUpdate }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool shouldStream;
  final InlineCard inlineCard;

  bool get fromUser => role == MessageRole.user;

  ChatMessage({
    String? id,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.shouldStream = false,
    this.inlineCard = InlineCard.none,
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

  String get timeLabel {
    final h = timestamp.hour;
    final m = timestamp.minute.toString().padLeft(2, '0');
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }
}
