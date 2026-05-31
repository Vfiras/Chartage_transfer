import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'chat_message_model.dart';
import 'demo_conversation_repository.dart';

class AssistantController extends ChangeNotifier {
  final _messages = <ChatMessage>[];
  // IDs of assistant messages that have already played their streaming
  // animation. Once here, the bubble renders full text instantly — so
  // scrolling away and back never re-triggers the typewriter effect.
  final _streamedIds = <String>{};
  bool _isTyping = false;
  bool _isSending = false;

  AssistantController({String userFirstName = 'there'}) {
    _seedShowcase(userFirstName);
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isSending => _isSending;
  bool get canSend => !_isSending && !_isTyping;

  bool hasStreamed(String id) => _streamedIds.contains(id);
  void markStreamed(String id) => _streamedIds.add(id);

  // Seeds an elegant pre-existing conversation so the screen looks alive
  // on first open (matches the Stitch showcase). These are historical and
  // do not stream.
  void _seedShowcase(String name) {
    final base = DateTime.now();
    _messages.addAll([
      ChatMessage(
        role: MessageRole.assistant,
        timestamp: DateTime(base.year, base.month, base.day, 12, 42),
        text:
            "Good afternoon, $name. I noticed your flight into Tunis-Carthage tomorrow arrives 15 minutes early. Would you like me to adjust the chauffeur's arrival time accordingly?",
      ),
      ChatMessage(
        role: MessageRole.user,
        timestamp: DateTime(base.year, base.month, base.day, 12, 45),
        text:
            "Yes, please. That would be perfect. Also, can we ensure there is sparkling water in the car?",
      ),
      ChatMessage(
        role: MessageRole.assistant,
        timestamp: DateTime(base.year, base.month, base.day, 12, 46),
        inlineCard: InlineCard.scheduleUpdate,
        text:
            "Certainly. I have updated the schedule and noted your refreshment preference. Here is your updated trip brief:",
      ),
    ]);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !canSend) return;

    _isSending = true;
    _messages.add(ChatMessage.user(trimmed));
    notifyListeners();

    // Typing delay: 1.5–2.1 s  (looks natural, not mechanical)
    _isTyping = true;
    notifyListeners();

    await Future<void>.delayed(
      Duration(milliseconds: 1500 + Random().nextInt(600)),
    );

    _isTyping = false;
    _isSending = false;

    final reply = DemoConversationRepository.getResponse(trimmed);
    _messages.add(ChatMessage.assistant(reply, stream: true));
    notifyListeners();
  }
}
