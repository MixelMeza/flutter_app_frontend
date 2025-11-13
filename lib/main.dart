import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'widgets/login_version7.dart';
import 'widgets/register_version7.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'widgets/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isDark = false;
  bool _showRegister = false;
  bool _loggedIn = false;
  String _userRole = 'inquilino';
  String? _displayName;
  String? _prefillEmail;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Map<String, dynamic>? _cachedProfile;

  @override
  void initState() {
    super.initState();
    _initFromStorage();
  }

  Future<void> _initFromStorage() async {
    // load token from secure storage
    await ApiService.loadAuthToken();
    // load cached profile
    final profile = await CacheService.getProfile();
    if (profile != null) {
      setState(() {
        _cachedProfile = profile;
        _displayName = profile['nombre'] ?? profile['user'] ?? profile['username'] ?? profile['email'];
        _prefillEmail = profile['email'] ?? _prefillEmail;
        // attempt to determine role from cached profile
        final maybe = profile['rol'] ?? profile['role'] ?? profile['tipo'] ?? profile['rol_id'] ?? profile['roles'];
        if (maybe is String) {
          final lower = maybe.toLowerCase();
          if (lower.contains('propiet') || lower.contains('owner')) _userRole = 'propietario';
          else if (lower.contains('admin')) _userRole = 'admin';
          else _userRole = 'inquilino';
        } else if (maybe is int) {
          if (maybe == 1) _userRole = 'propietario';
          else if (maybe == 2) _userRole = 'inquilino';
        }
      });
    }

    // If we have connectivity and a token, try refreshing profile in background
    final conn = await Connectivity().checkConnectivity();
    if (conn != ConnectivityResult.none && ApiService.authToken != null) {
      try {
        final me = await ApiService.get('/api/usuarios/me', token: ApiService.authToken);
        if (me is Map<String, dynamic>) {
          await CacheService.saveProfile(me);
          setState(() {
            _cachedProfile = me;
            _displayName = me['nombre'] ?? me['user'] ?? me['username'] ?? me['email'];
            final maybe = me['rol'] ?? me['role'] ?? me['tipo'] ?? me['rol_id'] ?? me['roles'];
            if (maybe is String) {
              final lower = maybe.toLowerCase();
              if (lower.contains('propiet') || lower.contains('owner')) _userRole = 'propietario';
              else if (lower.contains('admin')) _userRole = 'admin';
              else _userRole = 'inquilino';
            } else if (maybe is int) {
              if (maybe == 1) _userRole = 'propietario';
              else if (maybe == 2) _userRole = 'inquilino';
            }
            _loggedIn = true; // if token exists and /me returned, consider logged in
          });
        }
      } catch (_) {
        // ignore background refresh errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDark ? AppTheme.darkTheme() : AppTheme.lightTheme();

    return AnimatedTheme(
      data: themeData,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        navigatorKey: _navigatorKey,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('en', ''),
        ],
        theme: themeData,
        home: Scaffold(
          body: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: (() {
                  // build the appropriate child to avoid complex nested ternaries inline
                  if (_loggedIn) {
                    return HomePage(
                      key: const ValueKey('home'),
                      email: _prefillEmail,
                      displayName: _displayName,
                      profile: _cachedProfile,
                      role: _userRole,
                      onLogout: () async {
                        await ApiService.clearAuthToken();
                        await CacheService.clearProfile();
                        setState(() {
                          _loggedIn = false;
                          _prefillEmail = null;
                          _showRegister = false;
                          _userRole = 'inquilino';
                          _displayName = null;
                          _cachedProfile = null;
                        });
                        _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
                      },
                    );
                  }

                  if (_showRegister) {
                    return RegisterVersion7(
                      key: const ValueKey('register'),
                      appName: 'LivUp',
                      logo: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: Image.asset(
                            'assets/logo.png',
                            width: 106,
                            height: 106,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      isDarkMode: _isDark,
                      onToggleTheme: (v) => setState(() => _isDark = v),
                        onRegister: (data) async {
                        // show loading dialog
                          // show a modal or inline progress instead of a SnackBar that may block navigation.
                          // We avoid showing a success SnackBar on registration/login per UX request.

                          try {
                            final resp = await ApiService.registerUser(data);
                            // prefer email from response, fallback to payload
                            // Prefer the email the user typed in the form. If that's
                            // not available, fall back to the API response `email`,
                            // then to `username` if the backend returns that instead.
                            String email = '';
                            try {
                              final maybeEmail = (data['email'] ?? '') as String;
                              if (maybeEmail.trim().isNotEmpty) {
                                  email = maybeEmail.trim();
                                } else {
                                final respEmail = resp['email'];
                                final respUser = resp['username'];
                                if (respEmail is String && respEmail.trim().isNotEmpty) {
                                  email = respEmail.trim();
                                } else if (respUser is String && respUser.trim().isNotEmpty) {
                                  email = respUser.trim();
                                }
                              }
                            } catch (_) {}

                              // also derive a display name (username) to show on login
                              String? displayName;
                              try {
                                final maybeUser = (data['username'] ?? data['user'] ?? '') as String;
                                if (maybeUser.trim().isNotEmpty) displayName = maybeUser.trim();
                              } catch (_) {}
                              try {
                                if (displayName == null || displayName.isEmpty) {
                                  final respUser = resp['username'];
                                  final respName = resp['nombre'];
                                  final respLast = resp['apellido'];
                                  if (respUser is String && respUser.trim().isNotEmpty) displayName = respUser.trim();
                                  else if (respName is String && respName.trim().isNotEmpty) {
                                    final last = (respLast is String) ? respLast : '';
                                    displayName = ('${respName} ${last}').trim();
                                  }
                                }
                              } catch (_) {}

                              setState(() {
                                _prefillEmail = email;
                                _displayName = displayName;
                                _showRegister = false;
                              });
                              // Do not show success SnackBar on registration to avoid blocking navigation.
                          } catch (e) {
                            _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Error al registrar: ${e.toString()}')));
                          }
                      },
                      onLogin: () => setState(() => _showRegister = false),
                    );
                  }

                  // default: login
                  return LoginVersion7(
                    key: const ValueKey('login'),
                    appName: 'LivUp',
                    logo: ClipOval(
                      child: Container(
                        color: Colors.white,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 106,
                          height: 106,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    isDarkMode: _isDark,
                    onToggleTheme: (v) => setState(() => _isDark = v),
                    initialEmail: _prefillEmail,
                    onLogin: (email, pass) async {
                      // Show a modal loading indicator while attempting login.
                      bool dialogShown = false;
                      try {
                        dialogShown = true;
                        final navContext = _navigatorKey.currentContext ?? context;
                        showDialog(
                          context: navContext,
                          barrierDismissible: false,
                          useRootNavigator: true,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        await ApiService.login(email, pass);
                        // Try to fetch the current user's profile to determine role.
                        try {
                            // first try to extract role from token directly (faster)
                            String? detectedRole;
                            try {
                              detectedRole = _roleFromToken(ApiService.authToken);
                            } catch (_) {
                              detectedRole = null;
                            }
                            // also attempt to extract a username/display name from token
                            try {
                              _displayName = _userFromToken(ApiService.authToken);
                            } catch (_) {
                              _displayName = null;
                            }

                            if (detectedRole != null) {
                              _userRole = detectedRole;
                            } else {
                              final me = await ApiService.get('/api/usuarios/me', token: ApiService.authToken);
                              if (me is Map) {
                                // cache profile for offline use
                                try {
                                  await CacheService.saveProfile(me.cast<String, dynamic>());
                                  _cachedProfile = me.cast<String, dynamic>();
                                } catch (_) {}
                                // common fields: rol, rol_id, role, roles, tipo
                                final maybeRole = (me['rol'] ?? me['role'] ?? me['tipo'] ?? me['rol_id'] ?? me['roles']);
                                if (maybeRole is String) {
                                  final lower = maybeRole.toLowerCase();
                                  if (lower.contains('propiet') || lower.contains('owner')) {
                                    _userRole = 'propietario';
                                  } else if (lower.contains('admin')) {
                                    _userRole = 'admin';
                                  } else {
                                    _userRole = 'inquilino';
                                  }
                                } else if (maybeRole is int) {
                                  // assume 1=propietario, 2=inquilino (as used elsewhere)
                                  if (maybeRole == 1) _userRole = 'propietario';
                                  else if (maybeRole == 2) _userRole = 'inquilino';
                                }
                              }
                            }
                          
                        } catch (_) {
                          // ignore, keep default role
                        }
                        if (dialogShown) {
                          if (_navigatorKey.currentState?.canPop() == true) {
                            _navigatorKey.currentState?.pop();
                          }
                        }
                        setState(() {
                          _loggedIn = true;
                          _prefillEmail = email;
                        });
                        // Do not show success message on login; only surface errors.
                      } catch (e) {
                        if (dialogShown) {
                          if (_navigatorKey.currentState?.canPop() == true) {
                            _navigatorKey.currentState?.pop();
                          }
                        }
                        // If credentials error (401) let the login form handle field errors
                        if (e is ApiException && e.statusCode == 401) {
                          rethrow;
                        }

                        // Show styled error only for server/internal errors (status >= 500)
                        if (e is ApiException) {
                          final code = e.statusCode;
                          if (code == null || code >= 500) {
                            var msg = e.message;
                            _showStyledMessage('Error al iniciar sesión: $msg', MessageSeverity.error);
                          } else {
                            // for other client errors (4xx) do not show global notification
                            // the login form should handle field-level errors when appropriate
                          }
                        } else {
                          // Non-ApiException (network, timeout) - show as server-like error
                          _showStyledMessage('Error al iniciar sesión: ${e.toString()}', MessageSeverity.error);
                        }
                      }
                    },
                    onForgotPassword: () {
                      _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Olvidé contraseña')));
                    },
                    onRegister: () => setState(() => _showRegister = true),
                  );
                }()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStyledMessage(String text, MessageSeverity severity) {
    final color = severity == MessageSeverity.success
        ? Colors.green[700]
        : severity == MessageSeverity.warning
            ? Colors.orange[800]
            : Colors.red[700];

    final icon = severity == MessageSeverity.success
        ? Icons.check_circle
        : severity == MessageSeverity.warning
            ? Icons.warning_amber_rounded
            : Icons.error_outline;

    _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  }
}

enum MessageSeverity { success, warning, error }

  // Attempt to extract a role string from a JWT token.
  // This reads the JWT payload (base64url), parses JSON and looks for
  // role-like claims. If an encrypted claim exists (role_enc) it will
  // try a base64 decode and treat the result as UTF-8 text or JSON.
  // NOTE: if the claim is actually ciphertext (IV+ciphertext) we cannot
  // decrypt it here without the key; this function only attempts
  // best-effort decoding of plain/base64-encoded content.
  String? _roleFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payloadPart = parts[1];
      String normalized = base64Url.normalize(payloadPart);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map payload = jsonDecode(decoded) as Map;
      // look for common fields
      final candidates = [
        payload['role'],
        payload['rol'],
        payload['tipo'],
        payload['roles'],
        payload['role_enc'],
        payload['roleEncoded'],
      ];
      for (final c in candidates) {
        if (c == null) continue;
        if (c is String) {
          final s = c.trim();
          if (s.isEmpty) continue;
          // If it's a base64 block, try to decode and see if it's readable
          if (_looksLikeBase64(s)) {
            try {
              final raw = base64.decode(s);
              final asText = utf8.decode(raw);
              // JSON?
              try {
                final parsed = jsonDecode(asText);
                if (parsed is Map) {
                  final r = parsed['role'] ?? parsed['rol'] ?? parsed['tipo'];
                  if (r is String && r.isNotEmpty) return _normalizeRole(r);
                }
              } catch (_) {
                // not JSON, use asText directly
                if (asText.isNotEmpty) return _normalizeRole(asText);
              }
            } catch (_) {
              // not decodable; fall back to raw string
              return _normalizeRole(s);
            }
          } else {
            return _normalizeRole(s);
          }
        } else if (c is int) {
          if (c == 1) return 'propietario';
          if (c == 2) return 'inquilino';
        } else if (c is List && c.isNotEmpty) {
          final first = c.first;
          if (first is String) return _normalizeRole(first);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _looksLikeBase64(String s) {
    // crude check: base64 typically uses these chars and length mod 4
    final b64 = RegExp(r'^[A-Za-z0-9+/=]+$');
    return b64.hasMatch(s) && (s.length % 4 == 0 || s.length % 4 == 2 || s.length % 4 == 3);
  }

  String _normalizeRole(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('propiet') || lower.contains('owner')) return 'propietario';
    if (lower.contains('admin')) return 'admin';
    if (lower.contains('inquil') || lower.contains('tenant')) return 'inquilino';
    // fallback: if contains 'prop' or 'propietario'
    if (lower.contains('prop')) return 'propietario';
    return 'inquilino';
  }

  // Try to extract a display username from token payload.
  String? _userFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payloadPart = parts[1];
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(payloadPart)));
      final Map payload = jsonDecode(decoded) as Map;
      // direct claims
      final direct = payload['user'] ?? payload['username'] ?? payload['uid'] ?? payload['sub'];
      if (direct is String && direct.trim().isNotEmpty) return direct.trim();
      // try encrypted claims that may be base64 of plaintext
      final enc = payload['user_enc'] ?? payload['uid_enc'] ?? payload['userEncoded'];
      if (enc is String && _looksLikeBase64(enc)) {
        try {
          final raw = base64.decode(enc);
          final asText = utf8.decode(raw);
          // if JSON inside
          try {
            final parsed = jsonDecode(asText);
            if (parsed is Map) {
              final maybe = parsed['user'] ?? parsed['username'] ?? parsed['uid'];
              if (maybe is String && maybe.trim().isNotEmpty) return maybe.trim();
            }
          } catch (_) {
            if (asText.trim().isNotEmpty) return asText.trim();
          }
        } catch (_) {
          // cannot decode encrypted blob
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
