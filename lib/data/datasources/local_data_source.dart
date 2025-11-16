import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalDataSource {
  Future<void> saveAuthToken(String token);
  Future<String?> getAuthToken();
  Future<void> clearAuthToken();
  Future<void> saveThemePreference(bool isDark);
  Future<bool?> getThemePreference();
  // Persist user role locally so the app can restore UI role state quickly
  Future<void> saveUserRole(String role);
  Future<String?> getUserRole();
  Future<void> clearUserRole();
}

class SharedPrefsLocalDataSource implements LocalDataSource {
  static const _tokenKey = 'auth_token_v1';
  static const _themeKey = 'user_pref_theme_dark_v1';
  static const _roleKey = 'cached_user_role_v1';

  @override
  Future<void> saveAuthToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, token);
  }

  @override
  Future<String?> getAuthToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKey);
  }

  @override
  Future<void> clearAuthToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
  }

  @override
  Future<void> saveThemePreference(bool isDark) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_themeKey, isDark);
  }

  @override
  Future<bool?> getThemePreference() async {
    final sp = await SharedPreferences.getInstance();
    if (!sp.containsKey(_themeKey)) return null;
    return sp.getBool(_themeKey);
  }

  @override
  Future<void> saveUserRole(String role) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_roleKey, role);
  }

  @override
  Future<String?> getUserRole() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_roleKey);
  }

  @override
  Future<void> clearUserRole() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_roleKey);
  }

}
