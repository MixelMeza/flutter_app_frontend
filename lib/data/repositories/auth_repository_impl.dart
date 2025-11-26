import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote_data_source.dart';
import '../datasources/local_data_source.dart';
import '../../services/api_service.dart' as api_service;

class AuthRepositoryImpl implements AuthRepository {
  final RemoteDataSource remote;
  final LocalDataSource local;

  AuthRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await remote.login(email, password);
    // Try to extract a token from common response shapes.
    String? extractToken(dynamic src) {
      if (src == null) return null;
      if (src is String) return src;
      if (src is Map<String, dynamic>) {
        final keys = ['token', 'accessToken', 'access_token', 'jwt', 'authToken', 'auth_token'];
        for (final k in keys) {
          final v = src[k];
          if (v is String && v.isNotEmpty) return v;
        }
        // also check nested common envelope keys
        if (src.containsKey('data') && src['data'] is Map<String, dynamic>) {
          final nested = extractToken(src['data']);
          if (nested != null && nested.isNotEmpty) return nested;
        }
      }
      return null;
    }

    final token = extractToken(result);
    if (token != null && token.isNotEmpty) {
      await local.saveAuthToken(token);
      // Also save to ApiService so in-memory token is populated for outgoing requests
      try {
        await api_service.ApiService.saveAuthToken(token);
      } catch (_) {
        // best-effort: if secure storage fails, keep token in local storage
        api_service.ApiService.authToken = token; // at least set in-memory
      }
    }
    return result;
  }

  @override
  Future<void> saveToken(String token) async => await local.saveAuthToken(token);

  @override
  Future<String?> getToken() async => await local.getAuthToken();

  @override
  Future<void> clearToken() async => await local.clearAuthToken();

  @override
  Future<Map<String, dynamic>> getProfile() async {
    final token = await local.getAuthToken();
    if (token == null) throw Exception('No token');
    return await remote.getProfile(token);
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
    final token = await local.getAuthToken();
    if (token == null) throw Exception('No token');
    final updated = await remote.updateProfile(updates, token);
    // Optionally update cached profile locally
    try {
      // local data source may expose a saveProfile method; if not, use CacheService elsewhere
    } catch (_) {}
    return updated;
  }

  @override
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> payload) async {
    // forward registration to remote data source and return created user
    final result = await remote.registerUser(payload);
    return result;
  }
}
