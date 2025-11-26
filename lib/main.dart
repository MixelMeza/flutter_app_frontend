import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'di/locator.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'data/datasources/local_data_source.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/get_profile_usecase.dart';
import 'domain/usecases/register_user_usecase.dart';
import 'domain/usecases/update_profile_usecase.dart';
import 'widgets/login_version7.dart';
import 'widgets/register_version7.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
// connectivity import removed — not used in this file
import 'widgets/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Limit ImageCache to reduce memory pressure on startup and during navigation.
  // These are conservative defaults; adjust as needed.
  try {
    PaintingBinding.instance.imageCache.maximumSize = 100; // items
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // ~50 MB
  } catch (_) {}
  await setupLocator();

  // Resolve required usecases and local data source here so we fail fast
  final loginUseCase = locator<LoginUseCase>();
  final logoutUseCase = locator<LogoutUseCase>();
  final getProfileUseCase = locator<GetProfileUseCase>();
  final registerUseCase = locator<RegisterUserUseCase>();
  final updateProfileUseCase = locator<UpdateProfileUseCase>();
  final localDataSource = locator<LocalDataSource>();

  runApp(MainApp(
    loginUseCase: loginUseCase,
    logoutUseCase: logoutUseCase,
    getProfileUseCase: getProfileUseCase,
    registerUseCase: registerUseCase,
    updateUseCase: updateProfileUseCase,
    localDataSource: localDataSource,
  ));
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getProfileUseCase,
    required this.registerUseCase,
    required this.updateUseCase,
    required this.localDataSource,
  });

  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetProfileUseCase getProfileUseCase;
  final RegisterUserUseCase registerUseCase;
  final UpdateProfileUseCase updateUseCase;
  final LocalDataSource localDataSource;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _showRegister = false;
  String? _prefillEmail;
  String? _displayName;
  Map<String, dynamic>? _cachedProfile;
  String? _cachedRole;
  bool _hasValidToken = false;
  // _localToken removed (not used) to avoid unused-field lint

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initFromStorage();
  }

  Future<void> _initFromStorage() async {
    try {
      final profile = await CacheService.getProfile();
      if (profile != null) {
        setState(() {
          _cachedProfile = profile;
          _displayName = profile['displayName'] ?? profile['nombre'] ?? profile['user'] ?? profile['username'] ?? profile['email'];
          _prefillEmail = profile['email'] ?? _prefillEmail;
        });
      }
    } catch (_) {}
    // read persisted role if any
    try {
      final r = await widget.localDataSource.getUserRole();
      if (r != null && r.isNotEmpty) {
        _cachedRole = r;
      }
    } catch (_) {}
    // Check if a local auth token exists and appears unexpired.
    try {
      final token = await widget.localDataSource.getAuthToken();
      if (token != null && token.isNotEmpty) {
        final parts = token.split('.');
        if (parts.length >= 2) {
          try {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final Map map = jsonDecode(decoded) as Map;
            final exp = map['exp'];
            if (exp == null) {
              // no expiry claim => assume valid
              _hasValidToken = true;
            } else {
              int expSec = 0;
              if (exp is int) {
                expSec = exp;
              } else if (exp is String) {
                expSec = int.tryParse(exp) ?? 0;
              }
              if (expSec > 0) {
                final expiry = DateTime.fromMillisecondsSinceEpoch(expSec * 1000);
                if (expiry.isAfter(DateTime.now())) {
                  _hasValidToken = true;
                }
              }
            }
          } catch (_) {
            // if parsing fails, be conservative and treat token as present (but not validated)
            _hasValidToken = true;
          }
        } else {
          // not a JWT; assume present
          _hasValidToken = true;
        }
      }
    } catch (_) {}
  }

  // Try to extract a normalized role string from a cached profile map.
  String _roleFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return 'inquilino';
    final maybe = profile['rol'] ?? profile['role'] ?? profile['tipo'] ?? profile['rol_id'] ?? profile['roles'];
    if (maybe is String) {
      final lower = maybe.toLowerCase();
      if (lower.contains('propiet') || lower.contains('owner')) return 'propietario';
      if (lower.contains('admin')) return 'admin';
      if (lower.contains('inquil') || lower.contains('tenant')) return 'inquilino';
      if (lower.contains('prop')) return 'propietario';
      return 'inquilino';
    } else if (maybe is int) {
      if (maybe == 1) return 'propietario';
      if (maybe == 2) return 'inquilino';
    } else if (maybe is List && maybe.isNotEmpty) {
      final first = maybe.first;
      if (first is String) return _roleFromProfile({'role': first});
    }
    return 'inquilino';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (context) {
        // Defer heavy provider initialization until after first frame so
        // the initial UI can render quickly and avoid blocking startup.
        final auth = AuthProvider(
          widget.loginUseCase,
          widget.logoutUseCase,
          widget.getProfileUseCase,
          widget.registerUseCase,
          widget.updateUseCase,
          widget.localDataSource,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) => auth.init());
        return auth;
      },
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final themeData = auth.isDark ? AppTheme.darkTheme() : AppTheme.lightTheme();

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
                body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                    child: (auth.loggedIn || (_hasValidToken && (_cachedProfile != null || _cachedRole != null)))
                        ? HomePage(
                          key: const ValueKey('home'),
                          email: _prefillEmail,
                          displayName: auth.displayName ?? _displayName,
                          profile: auth.profile ?? _cachedProfile,
                          role: auth.profile != null ? auth.role : (_cachedRole ?? _roleFromProfile(_cachedProfile)),
                          isDarkMode: auth.isDark,
                          onToggleTheme: (v) async => auth.toggleTheme(v),
                          onLogout: () async {
                            await auth.logout();
                            try {
                              await widget.localDataSource.clearAuthToken();
                            } catch (_) {}
                            setState(() {
                              _hasValidToken = false;
                              _cachedProfile = null;
                              _cachedRole = null;
                              _prefillEmail = null;
                              _displayName = null;
                            });
                            _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
                          },
                        )
                      : (_showRegister
                          ? RegisterVersion7(
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
                              isDarkMode: auth.isDark,
                              onToggleTheme: (v) => auth.toggleTheme(v),
                              onRegister: (data) async {
                                try {
                                  final resp = await auth.register(data);
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

                                  String? displayName;
                                  try {
                                    final maybeUser = (data['username'] ?? data['user'] ?? '') as String;
                                    if (maybeUser.trim().isNotEmpty) {
                                      displayName = maybeUser.trim();
                                    }
                                  } catch (_) {}
                                  try {
                                    if (displayName == null || displayName.isEmpty) {
                                      final respUser = resp['username'];
                                      final respName = resp['nombre'];
                                      final respLast = resp['apellido'];
                                      if (respUser is String && respUser.trim().isNotEmpty) {
                                        displayName = respUser.trim();
                                      } else if (respName is String && respName.trim().isNotEmpty) {
                                        final last = (respLast is String) ? respLast : '';
                                        displayName = ('$respName $last').trim();
                                      }
                                    }
                                  } catch (_) {}

                                  setState(() {
                                    _prefillEmail = email;
                                    _displayName = displayName;
                                    _showRegister = false;
                                  });
                                } catch (e) {
                                  _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Error al registrar: ${e.toString()}')));
                                }
                              },
                              onLogin: () => setState(() => _showRegister = false),
                            )
                          : LoginVersion7(
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
                              isDarkMode: auth.isDark,
                              onToggleTheme: (v) => auth.toggleTheme(v),
                              initialEmail: _prefillEmail,
                              onLogin: (email, pass) async {
                                final navContext = _navigatorKey.currentContext ?? context;
                                showDialog(
                                  context: navContext,
                                  barrierDismissible: false,
                                  useRootNavigator: true,
                                  builder: (_) => const Center(child: CircularProgressIndicator()),
                                );
                                try {
                                  await auth.login(email, pass);
                                  setState(() {
                                    _prefillEmail = email;
                                    _displayName = auth.displayName ?? _displayName;
                                  });
                                } catch (e) {
                                  if (e is ApiException && e.statusCode == 401) {
                                    rethrow;
                                  }
                                  if (e is ApiException) {
                                    final code = e.statusCode;
                                    if (code == null || code >= 500) {
                                      var msg = e.message;
                                      _showStyledMessage('Error al iniciar sesión: $msg', MessageSeverity.error);
                                    }
                                  } else {
                                    _showStyledMessage('Error al iniciar sesión: ${e.toString()}', MessageSeverity.error);
                                  }
                                } finally {
                                  if (_navigatorKey.currentState?.canPop() == true) _navigatorKey.currentState?.pop();
                                }
                              },
                              onForgotPassword: () {
                                _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Olvidé contraseña')));
                              },
                              onRegister: () => setState(() => _showRegister = true),
                            )),
                ),
              ),
            ),
          );
        },
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

