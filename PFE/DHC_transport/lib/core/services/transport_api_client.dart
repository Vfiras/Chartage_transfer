import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TransportApiException implements Exception {
  final String message;

  const TransportApiException(this.message);

  @override
  String toString() => message;
}

class TransportApiClient {
  TransportApiClient._();

  static final TransportApiClient instance = TransportApiClient._();

  static String get defaultBaseUrl {
    const override = String.fromEnvironment('DHC_API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8080/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }

    return 'http://127.0.0.1:8080/api/v1';
  }

  final http.Client _client = http.Client();
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    return _send('PUT', path, body: body);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) {
    return _send('PATCH', path, body: body, query: query);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send('DELETE', path);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri =
        Uri.parse('$defaultBaseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => _client.put(uri, headers: headers, body: encodedBody),
      'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw const TransportApiException('Unsupported request method'),
    }
        .timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const TransportApiException(
          'Could not reach the server. Check that the backend is running.'),
    );

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransportApiException(
          decoded['detail']?.toString() ?? 'API request failed');
    }

    return decoded;
  }
}
