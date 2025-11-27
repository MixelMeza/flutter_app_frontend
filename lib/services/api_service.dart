import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:async' show TimeoutException;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api.dart';
import 'dart:async';

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

  // Broadcast stream for global auth errors (e.g., 401 Unauthorized).
  static final StreamController<void> _authErrorController =
      StreamController<void>.broadcast();
  static Stream<void> get onAuthError => _authErrorController.stream;
  static void notifyAuthError() {
    try {
      _authErrorController.add(null);
    } catch (_) {}
  }

  // Login: returns token string on success
  static Future<String> login(String usernameOrEmail, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    // Enviar ambas llaves para máxima compatibilidad (algunos backends usan 'email', otros 'username').
    final body = jsonEncode({
      'username': usernameOrEmail,
      'email': usernameOrEmail,
      'password': password,
    });

    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: defaultJsonHeaders(), body: body)
          .timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException(
        'Connection error: unable to reach $baseUrl (${e.message})',
      );
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

    // Si es login y el status es 400/401/415, no mostrar body ni detalles
    if (uri.path.contains('/login')) {
      throw ApiException('Contraseña incorrecta', statusCode: resp.statusCode);
    }

    // decode body to preserve accents/encoding
    final errBody = utf8.decode(resp.bodyBytes);
    throw ApiException(
      'Login failed',
      statusCode: resp.statusCode,
      body: errBody,
    );
  }

  // Register user: sends UsuarioCreateDTO payload and returns created usuario JSON
  static Future<Map<String, dynamic>> registerUser(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/usuarios');
    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: defaultJsonHeaders(token),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException(
        'Connection error: unable to reach $baseUrl (${e.message})',
      );
    } on TimeoutException catch (_) {
      throw ApiException('Request timeout: no response from $baseUrl');
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = utf8.decode(resp.bodyBytes);
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      return data;
    }
    final errBody = utf8.decode(resp.bodyBytes);
    if (resp.statusCode == 401) notifyAuthError();
    throw ApiException(
      'Register failed',
      statusCode: resp.statusCode,
      body: errBody,
    );
  }

  // Generic GET helper
  static Future<dynamic> get(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: defaultJsonHeaders(token))
          .timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException(
        'Connection error: unable to reach $baseUrl (${e.message})',
      );
    } on TimeoutException catch (_) {
      throw ApiException('Request timeout: no response from $baseUrl');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = utf8.decode(resp.bodyBytes);
      return jsonDecode(decoded);
    }
    final errBody = utf8.decode(resp.bodyBytes);
    if (resp.statusCode == 401) notifyAuthError();
    throw ApiException(
      'GET $path failed',
      statusCode: resp.statusCode,
      body: errBody,
    );
  }

  /// Change password: sends current and new password to backend
  /// Returns success message on 200/201, throws ApiException on error
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/change-password');
    final effectiveToken = token ?? authToken;

    // Debug logging
    debugPrint('=== CHANGE PASSWORD REQUEST ===');
    debugPrint('URL: $uri');
    debugPrint(
      'Has token: ${effectiveToken != null && effectiveToken.isNotEmpty}',
    );
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      debugPrint(
        'Token (first 20 chars): ${effectiveToken.substring(0, effectiveToken.length > 20 ? 20 : effectiveToken.length)}...',
      );
    }

    if (effectiveToken == null || effectiveToken.isEmpty) {
      debugPrint('ERROR: No authentication token available');
      throw ApiException('No authentication token available');
    }

    final payload = {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };

    debugPrint('Payload keys: ${payload.keys.toList()}');

    http.Response resp;
    try {
      final headers = defaultJsonHeaders(effectiveToken);
      debugPrint('Request headers: $headers');

      resp = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');
      debugPrint('Response headers: ${resp.headers}');
    } on SocketException catch (e) {
      debugPrint('Socket Exception: ${e.message}');
      throw ApiException(
        'Connection error: unable to reach $baseUrl (${e.message})',
      );
    } on TimeoutException catch (_) {
      debugPrint('Timeout Exception');
      throw ApiException('Request timeout: no response from $baseUrl');
    } catch (e) {
      debugPrint('Unexpected error in HTTP request: $e');
      rethrow;
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = utf8.decode(resp.bodyBytes);
      debugPrint('Success! Decoded response: $decoded');

      // Try to parse as JSON, if it fails, treat as plain text
      try {
        final data = jsonDecode(decoded);
        if (data is Map<String, dynamic>) {
          return data;
        }
        // If it's not a map, return the data wrapped in a message
        return {'message': data.toString()};
      } catch (e) {
        // Response is plain text, not JSON
        debugPrint('Response is plain text, not JSON: $decoded');
        return {'message': decoded.trim()};
      }
    }

    final errBody = utf8.decode(resp.bodyBytes);
    debugPrint('Error response body: $errBody');

    // Try to extract error message from response
    String errorMsg = 'Error al cambiar contraseña';
    try {
      final errData = jsonDecode(errBody);
      if (errData is Map && errData['message'] != null) {
        errorMsg = errData['message'].toString();
      } else if (errData is Map && errData['error'] != null) {
        errorMsg = errData['error'].toString();
      }
    } catch (e) {
      debugPrint('Error parsing error response: $e');
      if (resp.statusCode == 401) {
        errorMsg = 'Contraseña actual incorrecta';
      } else if (resp.statusCode == 400) {
        errorMsg = 'Datos inválidos';
      } else if (resp.statusCode == 404) {
        errorMsg = 'Endpoint no encontrado (404)';
      }
    }
    debugPrint('Throwing ApiException: $errorMsg (status: ${resp.statusCode})');
    throw ApiException(errorMsg, statusCode: resp.statusCode, body: errBody);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    // Return a concise string; omit raw body to avoid huge red debug blocks in UI.
    if (statusCode != null) {
      return 'ApiException: $message (status: $statusCode)';
    }
    return 'ApiException: $message';
  }
}
