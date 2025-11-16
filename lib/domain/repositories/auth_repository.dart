abstract class AuthRepository {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> clearToken();
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> getProfile();
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates);
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> payload);
}
