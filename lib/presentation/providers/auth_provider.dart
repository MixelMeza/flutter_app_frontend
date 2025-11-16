import 'package:flutter/material.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/register_user_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../data/datasources/local_data_source.dart';
import '../../services/cache_service.dart';
import '../../core/network/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final GetProfileUseCase _getProfile;
  final RegisterUserUseCase _registerUser;
  final UpdateProfileUseCase _updateProfile;
  final LocalDataSource _localDataSource;

  bool isDark = false;
  bool loggedIn = false;
  Map<String, dynamic>? profile;
  String? displayName;
  String role = 'inquilino';

  AuthProvider(this._login, this._logout, this._getProfile, this._registerUser, this._updateProfile, this._localDataSource);

  Future<void> init() async {
    try {
      final themePref = await _localDataSource.getThemePreference();
      if (themePref != null) isDark = themePref;
    } catch (_) {}

    try {
      final me = await _getProfile.call();
      profile = me;
      try {
        await CacheService.saveProfile(me);
      } catch (_) {}
      displayName = me['displayName'] ?? me['nombre'] ?? me['user'] ?? me['username'] ?? me['email'];
      final maybe = me['rol'] ?? me['role'] ?? me['tipo'] ?? me['rol_id'] ?? me['roles'];
      if (maybe is String) {
        final lower = maybe.toLowerCase();
        if (lower.contains('propiet') || lower.contains('owner')) role = 'propietario';
        else if (lower.contains('admin')) role = 'admin';
        else role = 'inquilino';
      } else if (maybe is int) {
        if (maybe == 1) role = 'propietario';
        else if (maybe == 2) role = 'inquilino';
      }
      // persist role locally so app can restore UI quickly
      try {
        await _localDataSource.saveUserRole(role);
      } catch (_) {}
      loggedIn = true;
    } catch (_) {}

    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _login.call(email, password);
    // refresh profile
    try {
      final me = await _getProfile.call();
      profile = me;
      try {
        await CacheService.saveProfile(me);
      } catch (_) {}
      displayName = me['displayName'] ?? me['nombre'] ?? me['user'] ?? me['username'] ?? me['email'];
      final maybe = me['rol'] ?? me['role'] ?? me['tipo'] ?? me['rol_id'] ?? me['roles'];
      if (maybe is String) {
        final lower = maybe.toLowerCase();
        if (lower.contains('propiet') || lower.contains('owner')) role = 'propietario';
        else if (lower.contains('admin')) role = 'admin';
        else role = 'inquilino';
      } else if (maybe is int) {
        if (maybe == 1) role = 'propietario';
        else if (maybe == 2) role = 'inquilino';
      }
        try {
          await _localDataSource.saveUserRole(role);
        } catch (_) {}
      loggedIn = true;
    } catch (_) {
      loggedIn = true;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _logout.call();
    await CacheService.clearProfile();
    try {
      await _localDataSource.clearAuthToken();
    } catch (_) {}
    try {
      await _localDataSource.clearUserRole();
    } catch (_) {}
    profile = null;
    displayName = null;
    role = 'inquilino';
    loggedIn = false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool v) async {
    isDark = v;
    try {
      await _localDataSource.saveThemePreference(v);
    } catch (_) {}
    notifyListeners();
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    return await _registerUser.call(payload);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
    try {
      final updated = await _updateProfile.call(updates);
      profile = updated;
      displayName = updated['displayName'] ?? updated['nombre'] ?? updated['username'] ?? updated['email'];
      try {
        await CacheService.saveProfile(updated);
      } catch (_) {}
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // token expired or unauthorized — clear session
        try {
          await logout();
        } catch (_) {}
        throw Exception('Token expirado. Se ha cerrado la sesión.');
      }
      rethrow;
    }
  }

  /// Update profile locally (no server call). Persists to cache and notifies listeners.
  Future<void> setLocalProfile(Map<String, dynamic> newProfile) async {
    profile = newProfile;
    try {
      debugPrint('[AuthProvider] setLocalProfile called, foto_url=' + (newProfile['foto_url']?.toString() ?? '<none>'));
    } catch (_) {}
    displayName = newProfile['displayName'] ?? newProfile['nombre'] ?? newProfile['username'] ?? newProfile['email'];
    try {
      await CacheService.saveProfile(newProfile);
    } catch (_) {}
    notifyListeners();
  }
}
