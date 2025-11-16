import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _profileKey = 'cached_user_profile_v1';
  static const _themePrefKey = 'user_pref_theme_dark_v1';

  /// Save the profile map as JSON string in SharedPreferences
  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final sp = await SharedPreferences.getInstance();
    final json = jsonEncode(profile);
    await sp.setString(_profileKey, json);
  }

  /// Return cached profile or null if none
  static Future<Map<String, dynamic>?> getProfile() async {
    final sp = await SharedPreferences.getInstance();
    final json = sp.getString(_profileKey);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearProfile() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_profileKey);
  }

  /// Persist a boolean theme preference (true = dark, false = light)
  static Future<void> saveThemePreference(bool isDark) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_themePrefKey, isDark);
  }

  /// Return stored theme preference or null if none saved
  static Future<bool?> getThemePreference() async {
    final sp = await SharedPreferences.getInstance();
    if (!sp.containsKey(_themePrefKey)) return null;
    return sp.getBool(_themePrefKey);
  }
}
