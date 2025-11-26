import 'dart:convert';
import '../../core/network/api_client.dart';

abstract class RemoteDataSource {
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> getProfile(String token);
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates, String token);
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> payload);
}

class RemoteDataSourceImpl implements RemoteDataSource {
  final ApiClient client;

  RemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    // Try multiple tolerant login payloads to handle backend variations.
    final identifier = email.trim();
    final bool looksLikeEmail = identifier.contains('@');

    final attempts = <Map<String, dynamic>>[];
    // Preferred attempt: JSON with username/email appropriately
    if (looksLikeEmail) {
      attempts.add({'email': identifier, 'password': password});
      attempts.add({'username': identifier, 'password': password});
    } else {
      attempts.add({'username': identifier, 'password': password});
      attempts.add({'email': identifier, 'password': password});
    }

    // We'll also try form-urlencoded variants if JSON fails.
    final triedResponses = <String>[];

    for (final payload in attempts) {
      final body = jsonEncode(payload);
      try {
        final resp = await client.post('/api/auth/login', headers: {'Content-Type': 'application/json'}, body: body);
        final decoded = utf8.decode(resp.bodyBytes);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(decoded);
          if (data is Map<String, dynamic>) return data;
          return Map<String, dynamic>.from(data);
        }
        triedResponses.add('JSON ${payload.keys.toList()} => ${resp.statusCode} | $decoded');
      } catch (e) {
        triedResponses.add('JSON ${payload.keys.toList()} => EXCEPTION: ${e.toString()}');
      }
    }

    // Try form-urlencoded variants as last resort
    for (final payload in attempts) {
      final formBody = payload.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}').join('&');
      try {
        final resp = await client.post('/api/auth/login', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: formBody);
        final decoded = utf8.decode(resp.bodyBytes);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(decoded);
          if (data is Map<String, dynamic>) return data;
          return Map<String, dynamic>.from(data);
        }
        triedResponses.add('FORM ${payload.keys.toList()} => ${resp.statusCode} | $decoded');
      } catch (e) {
        triedResponses.add('FORM ${payload.keys.toList()} => EXCEPTION: ${e.toString()}');
      }
    }

    // If we received a WWW-Authenticate header indicating Basic auth is
    // required, try Basic auth as a last resort. ApiClient will store any
    // session cookie returned so subsequent requests can use it.
    try {
      final basic = base64.encode(utf8.encode('$identifier:$password'));
      final resp = await client.post('/api/auth/login', headers: {'Authorization': 'Basic $basic'});
      final decoded = utf8.decode(resp.bodyBytes);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(decoded);
        if (data is Map<String, dynamic>) return data;
        return Map<String, dynamic>.from(data);
      }
      triedResponses.add('BASIC => ${resp.statusCode} | $decoded');
    } catch (e) {
      triedResponses.add('BASIC => EXCEPTION: ${e.toString()}');
    }

    // none succeeded
    throw Exception('Login failed (401). Attempts: ${triedResponses.join(' || ')}');
  }

  @override
  Future<Map<String, dynamic>> getProfile(String token) async {
    final resp = await client.get('/api/usuarios/me', headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = utf8.decode(resp.bodyBytes);
      final data = jsonDecode(decoded);
      if (data is Map<String, dynamic>) return data;
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Get profile failed: ${resp.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates, String token) async {
    final body = jsonEncode(updates);
    // Preferred: use PUT as specified by the API
    final resp = await client.put('/api/usuarios/me', headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
    final decoded = utf8.decode(resp.bodyBytes);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(decoded);
      if (data is Map<String, dynamic>) return data;
      return Map<String, dynamic>.from(data);
    }

    // Do not attempt POST fallback - server expects PUT for /me. Surface detailed error.
    throw Exception('Update profile failed: ${resp.statusCode} BODY:$decoded');
  }

  @override
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> payload) async {
    final body = jsonEncode(payload);
    final resp = await client.post('/api/usuarios', headers: {'Content-Type': 'application/json'}, body: body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = utf8.decode(resp.bodyBytes);
      final data = jsonDecode(decoded);
      if (data is Map<String, dynamic>) return data;
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Register failed: ${resp.statusCode}');
  }
}
