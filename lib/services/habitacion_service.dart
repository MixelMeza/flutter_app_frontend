import 'package:http/http.dart' as http;
import '../config/api.dart';
import 'api_service.dart';
import '../domain/entities/habitacion.dart';

/// Service for interacting with Habitacion-related backend endpoints.
class HabitacionService {
  /// Get likes info for a habitacion: returns a map like {"count": 10, "likedByMe": true}
  static Future<Map<String, dynamic>> getLikesInfo(int habitacionId) async {
    final dynamic data = await ApiService.get(
      '/api/habitaciones/$habitacionId/likes',
      token: ApiService.authToken,
    );
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data);
  }

  /// Like a habitacion (requires authentication)
  static Future<void> like(int habitacionId) async {
    final uri = Uri.parse('$baseUrl/api/habitaciones/$habitacionId/like');
    final resp = await http.post(
      uri,
      headers: defaultJsonHeaders(ApiService.authToken),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        'Like failed',
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
  }

  /// Unlike a habitacion (requires authentication)
  static Future<void> unlike(int habitacionId) async {
    final uri = Uri.parse('$baseUrl/api/habitaciones/$habitacionId/like');
    final resp = await http.delete(
      uri,
      headers: defaultJsonHeaders(ApiService.authToken),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        'Unlike failed',
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
  }

  /// Record a view. If [sessionUuid] is provided it will be used for anonymous sessions.
  static Future<void> recordView(
    int habitacionId, {
    String? sessionUuid,
  }) async {
    var uriString = '$baseUrl/api/habitaciones/$habitacionId/view';
    if (sessionUuid != null && sessionUuid.isNotEmpty) {
      uriString += '?sessionUuid=${Uri.encodeComponent(sessionUuid)}';
    }
    final uri = Uri.parse(uriString);
    final resp = await http.post(
      uri,
      headers: defaultJsonHeaders(ApiService.authToken),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        'Record view failed',
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
  }

  /// Get recent views for the authenticated user
  static Future<List<dynamic>> recentForMe({int limit = 20}) async {
    final dynamic data = await ApiService.get(
      '/api/habitaciones/recent?limit=$limit',
      token: ApiService.authToken,
    );
    if (data is List) return data;
    return List<dynamic>.from(data);
  }

  /// Get recent views for a session (anonymous)
  static Future<List<dynamic>> recentForSession(
    String sessionUuid, {
    int limit = 20,
  }) async {
    final dynamic data = await ApiService.get(
      '/api/habitaciones/recent/session?sessionUuid=${Uri.encodeComponent(sessionUuid)}&limit=$limit',
    );
    if (data is List) return data;
    return List<dynamic>.from(data);
  }

  /// Helper to fetch habitaciones marked as 'destacado'. The backend must expose a suitable endpoint
  /// such as `/api/habitaciones?destacado=true`. If your backend uses another path, change accordingly.
  static Future<List<Habitacion>> fetchDestacados({int limit = 20}) async {
    final dynamic data = await ApiService.get(
      '/api/habitaciones?destacado=true&limit=$limit',
      token: ApiService.authToken,
    );
    if (data is List) {
      return data
          .map((e) => Habitacion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
