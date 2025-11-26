import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? body;

  ApiException({this.statusCode, required this.message, this.body});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message, body: $body)';
}

class ApiClient {
  final String baseUrl;
  final http.Client _client;
  final Map<String, String> _cookies = {};

  ApiClient({this.baseUrl = '', http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> post(String path, {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(_buildUrl(path));
    try {
      // Basic logging to help debug backend communication
      debugPrint('[ApiClient] POST $uri');
      final mergedHeaders = _prepareHeaders(headers);
      if (mergedHeaders.isNotEmpty) debugPrint('[ApiClient] Request headers: $mergedHeaders');
      if (body != null) debugPrint('[ApiClient] Request body: $body');
      final resp = await _client.post(uri, headers: mergedHeaders, body: body);
        // Response body may be binary; print as string for debugging
        final respBody = resp.body;
        debugPrint('[ApiClient] Response ${resp.statusCode} for $uri');
        debugPrint('[ApiClient] Response headers: ${resp.headers}');
        debugPrint('[ApiClient] Response body: $respBody');
      // Only treat 401 as an authorization/token problem when the request
      // included an Authorization header. For unauthenticated endpoints
      // (like login) we want to let callers handle 401 themselves.
      // Persist cookies from Set-Cookie header (simple parser: name=value)
      final setCookie = resp.headers['set-cookie'];
      if (setCookie != null && setCookie.trim().isNotEmpty) {
        try {
          final first = setCookie.split(',').first; // may contain multiple cookies
          final pair = first.split(';').first.trim();
          final idx = pair.indexOf('=');
          if (idx > 0) {
            final name = pair.substring(0, idx);
            final value = pair.substring(idx + 1);
            _cookies[name] = value;
            debugPrint('[ApiClient] Stored cookie: $name=$value');
          }
        } catch (_) {}
      }

      if (resp.statusCode == 401 && mergedHeaders['Authorization'] != null && mergedHeaders['Authorization']!.trim().isNotEmpty) {
        throw ApiException(statusCode: resp.statusCode, message: 'Unauthorized', body: respBody);
      }
      return resp;
    } catch (e, st) {
      debugPrint('[ApiClient] POST $uri failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse(_buildUrl(path));
    try {
      debugPrint('[ApiClient] GET $uri');
      if (headers != null) debugPrint('[ApiClient] Request headers: $headers');
      final mergedHeaders = _prepareHeaders(headers);
      if (mergedHeaders.isNotEmpty) debugPrint('[ApiClient] Request headers: $mergedHeaders');
      final resp = await _client.get(uri, headers: mergedHeaders);
      debugPrint('[ApiClient] Response ${resp.statusCode} for $uri');
      debugPrint('[ApiClient] Response body: ${resp.body}');
      final setCookie = resp.headers['set-cookie'];
      if (setCookie != null && setCookie.trim().isNotEmpty) {
        try {
          final first = setCookie.split(',').first;
          final pair = first.split(';').first.trim();
          final idx = pair.indexOf('=');
          if (idx > 0) {
            final name = pair.substring(0, idx);
            final value = pair.substring(idx + 1);
            _cookies[name] = value;
            debugPrint('[ApiClient] Stored cookie: $name=$value');
          }
        } catch (_) {}
      }
      if (resp.statusCode == 401 && mergedHeaders['Authorization'] != null && mergedHeaders['Authorization']!.trim().isNotEmpty) {
        throw ApiException(statusCode: resp.statusCode, message: 'Unauthorized', body: resp.body);
      }
      return resp;
    } catch (e, st) {
      debugPrint('[ApiClient] GET $uri failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<http.Response> put(String path, {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(_buildUrl(path));
    try {
      debugPrint('[ApiClient] PUT $uri');
      if (headers != null) debugPrint('[ApiClient] Request headers: $headers');
      if (body != null) debugPrint('[ApiClient] Request body: $body');
      final mergedHeaders = _prepareHeaders(headers);
      if (mergedHeaders.isNotEmpty) debugPrint('[ApiClient] Request headers: $mergedHeaders');
      if (body != null) debugPrint('[ApiClient] Request body: $body');
      final resp = await _client.put(uri, headers: mergedHeaders, body: body);
      debugPrint('[ApiClient] Response ${resp.statusCode} for $uri');
      debugPrint('[ApiClient] Response headers: ${resp.headers}');
      debugPrint('[ApiClient] Response body: ${resp.body}');
      final setCookie = resp.headers['set-cookie'];
      if (setCookie != null && setCookie.trim().isNotEmpty) {
        try {
          final first = setCookie.split(',').first;
          final pair = first.split(';').first.trim();
          final idx = pair.indexOf('=');
          if (idx > 0) {
            final name = pair.substring(0, idx);
            final value = pair.substring(idx + 1);
            _cookies[name] = value;
            debugPrint('[ApiClient] Stored cookie: $name=$value');
          }
        } catch (_) {}
      }
      if (resp.statusCode == 401 && mergedHeaders['Authorization'] != null && mergedHeaders['Authorization']!.trim().isNotEmpty) {
        throw ApiException(statusCode: resp.statusCode, message: 'Unauthorized', body: resp.body);
      }
      return resp;
    } catch (e, st) {
      debugPrint('[ApiClient] PUT $uri failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Map<String, String> _prepareHeaders(Map<String, String>? headers) {
    final out = <String, String>{};
    if (headers != null) out.addAll(headers);
    if (!_cookies.isEmpty && !out.containsKey('Cookie')) {
      final cookie = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      out['Cookie'] = cookie;
    }
    return out;
  }

  String _buildUrl(String path) {
    if (path.startsWith('http')) return path;
    if (baseUrl.isEmpty) return path;
    // Normalize to avoid double slashes when baseUrl ends with '/' and path
    // starts with '/'. Ensure exactly one slash between baseUrl and path.
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$base/$p';
  }
}
