import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'transport_api_client.dart';

class AssistantApiService {
  AssistantApiService._();
  static final AssistantApiService instance = AssistantApiService._();

  static const String _keyPrefix = 'assistant_thread_id_';

  /// Returns a stable per-user thread_id, creating one if it doesn't exist.
  /// Keyed by userId so different accounts on the same device get separate threads.
  Future<String> getOrCreateThreadId() async {
    final userId = AuthService.instance.currentUser?.id ?? 'anon';
    final key = '$_keyPrefix$userId';
    final prefs = await SharedPreferences.getInstance();
    var threadId = prefs.getString(key);
    if (threadId == null || threadId.isEmpty) {
      threadId =
          'flutter_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      await prefs.setString(key, threadId);
    }
    return threadId;
  }

  /// Sends [message] to POST /assistant/chat and yields one decoded JSON object
  /// per SSE event.  Stops after receiving 'done' or 'error'.
  ///
  /// Uses [TransportApiClient.defaultBaseUrl], which already resolves to
  /// http://10.0.2.2:8000/api/v1 on Android emulator and 127.0.0.1 elsewhere.
  Stream<Map<String, dynamic>> chat(
    String message,
    String threadId,
  ) async* {
    final token = AuthService.instance.token;
    final uri =
        Uri.parse('${TransportApiClient.defaultBaseUrl}/assistant/chat');

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({'message': message, 'thread_id': threadId});

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String detail;
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          detail = json['detail']?.toString() ?? body;
        } catch (_) {
          detail = body;
        }
        yield {'type': 'error', 'content': detail};
        return;
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final raw = trimmed.substring(5).trim();
        if (raw.isEmpty) continue;
        try {
          final event = jsonDecode(raw) as Map<String, dynamic>;
          yield event;
          final type = event['type'] as String? ?? '';
          if (type == 'done' || type == 'error') break;
        } catch (_) {
          // Skip malformed SSE lines
        }
      }
    } catch (e) {
      yield {'type': 'error', 'content': 'Connection error: $e'};
    } finally {
      client.close();
    }
  }
}
