import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:async' show TimeoutException;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api.dart';

class ApiService {
  // In-memory auth token. For persistence across app restarts, replace with
  // secure storage (e.g., flutter_secure_storage) or SharedPreferences.
  static String? authToken;
  static const _storageKey = 'livup_auth_token_v1';
  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Load token from secure storage into memory. Call once at startup.
  static Future<void> loadAuthToken() async {
    try {
      final t = await _secure.read(key: _storageKey);
      authToken = t;
    } catch (_) {
      authToken = null;
    }
  }

  /// Persist token to secure storage and set in-memory
  static Future<void> saveAuthToken(String token) async {
    authToken = token;
    try {
      await _secure.write(key: _storageKey, value: token);
    } catch (_) {}
  }

  /// Clear token from memory and secure storage
  static Future<void> clearAuthToken() async {
    authToken = null;
    try {
      await _secure.delete(key: _storageKey);
    } catch (_) {}
  }

  /// Backwards-friendly logout: clear token from storage and memory
  static Future<void> logout() async {
    await clearAuthToken();
  }
  // Login: returns token string on success
  static Future<String> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final body = jsonEncode({'username': username, 'password': password});

    http.Response resp;
    try {
      resp = await http.post(uri, headers: defaultJsonHeaders(), body: body).timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException('Connection error: unable to reach $baseUrl (${e.message})');
    } on TimeoutException catch (_) {
      throw ApiException('Request timeout: no response from $baseUrl');
    }
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = utf8.decode(resp.bodyBytes);
      final data = jsonDecode(decoded);
      if (data is Map && data['token'] != null) {
        final token = data['token'] as String;
        // persist securely
        await saveAuthToken(token);
        return token;
      }
      throw ApiException('Invalid login response');
    }

    // decode body to preserve accents/encoding
    final errBody = utf8.decode(resp.bodyBytes);
    throw ApiException('Login failed', statusCode: resp.statusCode, body: errBody);
  }

  // Register user: sends UsuarioCreateDTO payload and returns created usuario JSON
  static Future<Map<String, dynamic>> registerUser(Map<String, dynamic> payload, {String? token}) async {
    final uri = Uri.parse('$baseUrl/api/usuarios');
    http.Response resp;
    try {
      resp = await http.post(uri, headers: defaultJsonHeaders(token), body: jsonEncode(payload)).timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException('Connection error: unable to reach $baseUrl (${e.message})');
    } on TimeoutException catch (_) {
      throw ApiException('Request timeout: no response from $baseUrl');
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = utf8.decode(resp.bodyBytes);
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      return data;
    }

    final errBody = utf8.decode(resp.bodyBytes);
    throw ApiException('Register failed', statusCode: resp.statusCode, body: errBody);
  }

  // Generic GET helper
  static Future<dynamic> get(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response resp;
    try {
      resp = await http.get(uri, headers: defaultJsonHeaders(token)).timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException('Connection error: unable to reach $baseUrl (${e.message})');
    } on TimeoutException catch (_) {
      throw ApiException('Request timeout: no response from $baseUrl');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = utf8.decode(resp.bodyBytes);
      return jsonDecode(decoded);
    }
    final errBody = utf8.decode(resp.bodyBytes);
    throw ApiException('GET $path failed', statusCode: resp.statusCode, body: errBody);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'ApiException: $message (status: $statusCode) ${body ?? ''}';
}
