import 'package:flutter/foundation.dart';

import '../../core/services/assistant_api_service.dart';
import 'chat_message_model.dart';

class AssistantController extends ChangeNotifier {
  final _messages = <ChatMessage>[];
  final _streamedIds = <String>{};
  bool _isTyping = false;
  bool _isSending = false;
  bool _disposed = false;

  AssistantController({String userFirstName = 'there'});

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isSending => _isSending;
  bool get canSend => !_isSending && !_isTyping;

  bool hasStreamed(String id) => _streamedIds.contains(id);
  void markStreamed(String id) => _streamedIds.add(id);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !canSend) return;

    _isSending = true;
    _isTyping = true;
    _messages.add(ChatMessage.user(trimmed));
    _notify();

    final service = AssistantApiService.instance;
    final threadId = await service.getOrCreateThreadId();

    // Analytics payload arrives on its own SSE event just before `done`;
    // stash it so the done-handler can render an AnalyticsCard message.
    Map<String, dynamic>? pendingAnalytics;

    try {
      await for (final event in service.chat(trimmed, threadId)) {
        if (_disposed) break;
        final type = event['type'] as String? ?? '';

        if (type == 'token') {
          // Keep-alive or node-completion pulse — typing indicator stays on.
          // Nothing to render; the TypingIndicator widget is already visible.
        } else if (type == 'analytics') {
          pendingAnalytics =
              (event['content'] as Map?)?.cast<String, dynamic>();
        } else if (type == 'done') {
          _isTyping = false;
          _isSending = false;
          final content = (event['content'] as String? ?? '').trim();
          if (pendingAnalytics != null) {
            // Rich analytics response: KPIs + charts + insights card with the
            // analyst narrative as its text.
            _messages.add(ChatMessage.analytics(
              content.isEmpty ? 'Analysis complete.' : content,
              pendingAnalytics,
            ));
            pendingAnalytics = null;
            _notify();
            continue;
          }
          // Parse into a structured card where the text matches a known pattern;
          // unrecognized text yields cardType=none → the same plain bubble as before.
          _messages.add(ChatMessage.assistantParsed(
            content.isEmpty ? 'No response from AVA.' : content,
            stream: true,
          ));
          _notify();
        } else if (type == 'error') {
          _isTyping = false;
          _isSending = false;
          final raw = event['content'] as String? ?? '';
          _messages.add(ChatMessage.error(_friendlyError(raw)));
          _notify();
        }
      }
    } catch (e) {
      if (!_disposed) {
        _isTyping = false;
        _isSending = false;
        _messages.add(ChatMessage.error(
          'Could not reach AVA — check your connection and try again.',
        ));
        _notify();
      }
    }

    // Safety net: clear loading state if stream ended without done/error.
    if (_isTyping || _isSending) {
      _isTyping = false;
      _isSending = false;
      _notify();
    }
  }

  static String _friendlyError(String raw) {
    if (raw.contains('GOOGLE_API_KEY') || raw.contains('api key')) {
      return 'AVA is temporarily unavailable. Please try again in a moment.';
    }
    if (raw.startsWith('Connection error:') ||
        raw.contains('SocketException') ||
        raw.contains('HandshakeException')) {
      return 'Could not reach AVA — check your connection and try again.';
    }
    // HTTP 401, access denied, etc. — surface as-is; they're readable
    return raw;
  }
}
