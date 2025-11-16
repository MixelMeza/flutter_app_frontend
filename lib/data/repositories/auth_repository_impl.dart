import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote_data_source.dart';
import '../datasources/local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final RemoteDataSource remote;
  final LocalDataSource local;

  AuthRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await remote.login(email, password);
    // Expect token in result['token'] or similar - store if present
    final token = result['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await local.saveAuthToken(token);
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
