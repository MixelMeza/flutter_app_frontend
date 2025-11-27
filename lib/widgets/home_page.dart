import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/connectivity_provider.dart';
import '../presentation/providers/user_provider.dart';
// (no duplicate dart:convert import)

import 'package:intl/intl.dart';
import '../theme.dart';
import 'explore_map.dart';
import 'profile_edit.dart';
import 'change_password.dart';
import 'preferences.dart';
import 'leading_icon.dart';
import 'styled_card.dart';
import 'mis_residencias.dart';

// Top-level helper for compute() to decode base64 into bytes off the UI thread.
Uint8List _decodeBase64ToBytes(String b64) => base64Decode(b64);

/// Role-aware HomePage with BottomNavigationBar.
/// Accepts a `role` string: 'inquilino', 'propietario', 'admin'.
class HomePage extends StatefulWidget {
  final VoidCallback onLogout;
  final String? email;
  final String? displayName;
  final Map<String, dynamic>? profile;
  final String role;
  // Theme controls passed from parent
  final bool? isDarkMode;
  final ValueChanged<bool>? onToggleTheme;

  const HomePage({
    super.key,
    required this.onLogout,
    this.email,
    this.displayName,
    this.role = 'inquilino',
    this.profile,
    this.isDarkMode,
    this.onToggleTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();

  static Widget withUserProvider({
    required VoidCallback onLogout,
    String? email,
    String? displayName,
    Map<String, dynamic>? profile,
    String role = 'inquilino',
    bool? isDarkMode,
    ValueChanged<bool>? onToggleTheme,
  }) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider()..loadUsers(),
      child: HomePage(
        onLogout: onLogout,
        email: email,
        displayName: displayName,
        profile: profile,
        role: role,
        isDarkMode: isDarkMode,
        onToggleTheme: onToggleTheme,
      ),
    );
  }
}

/// Lightweight deferred loader for `ExploreMap`.
/// Shows a small placeholder for `delay` then replaces with the real map.
class _DeferredExplore extends StatefulWidget {
  const _DeferredExplore();

  @override
  State<_DeferredExplore> createState() => _DeferredExploreState();
}

class _DeferredExploreState extends State<_DeferredExplore> {
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _showMap = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showMap) return const ExploreMap();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.travel_explore, size: 48),
          const SizedBox(height: 8),
          Text(
            'Cargando mapa...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  // Controller for PageView: initialize with page 0 (same as _index).
  final PageController _pageController = PageController(initialPage: 0);

  // Build pages lazily by index to avoid instantiating heavy widgets
  // (like GoogleMap) during app startup which can cause JNI / I/O pressure
  // and trigger ANRs. PageView.builder below calls this when a page is needed.
  Widget _pageForIndex(int index, String role) {
    if (role == 'propietario') {
      switch (index) {
        case 0:
          return const _DeferredExplore();
        case 1:
          // Add a top padding so the header inside `MisResidencias` appears lower
          // without modifying the `mis_residencias.dart` file itself.
          return const Padding(
            padding: EdgeInsets.only(top: 56),
            child: MisResidencias(),
          );
        case 2:
          return _page('Principal', Icons.home);
        case 3:
          return _page('Contratos', Icons.description);
        case 4:
          return _profilePage();
      }
    }

    if (role == 'admin') {
      switch (index) {
        case 0:
          return const _DeferredExplore();
        case 1:
          return _page('Residencias', Icons.apartment);
        case 2:
          return _page('Usuarios', Icons.groups);
        case 3:
          return _profilePage();
      }
    }

    // default inquilino
    switch (index) {
      case 0:
        return const _DeferredExplore();
      case 1:
        return _page('Alquiler', Icons.key);
      case 2:
        return _page('Principal', Icons.home);
      case 3:
        return _page('Favoritos', Icons.favorite);
      case 4:
        return _profilePage();
    }

    return const SizedBox.shrink();
  }

  @override
  void initState() {
    super.initState();
    // PageController already initialized at declaration to avoid
    // late-initialization errors during hot-reload or testing.
    // No further action needed here; PageView will attach the controller.
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Fallback avatar widget when image can't be shown.
  Widget _avatarFallback(String displayName) {
    return Center(
      child: Text(
        displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildItems(String role) {
    if (role == 'propietario') {
      final auth = Provider.of<AuthProvider>(context, listen: true);
      final isLoading = auth.loadingResidencias;
      final iconWidget = isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(
                        context,
                      ).bottomNavigationBarTheme.selectedItemColor ??
                      AppColors.maroon,
                ),
              ),
            )
          : const Icon(Icons.apartment);
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.travel_explore),
          label: 'Explorar',
        ),
        BottomNavigationBarItem(icon: iconWidget, label: 'Resid.'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Principal'),
        BottomNavigationBarItem(
          icon: Icon(Icons.description),
          label: 'Contratos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle),
          label: 'Perfil',
        ),
      ];
    }

    if (role == 'admin') {
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.travel_explore),
          label: 'Explorar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.apartment),
          label: 'Residencias',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Usuarios'),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle),
          label: 'Perfil',
        ),
      ];
    }

    return [
      BottomNavigationBarItem(
        icon: Icon(Icons.travel_explore),
        label: 'Explorar',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.key), label: 'Alquiler'),
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Principal'),
      BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
      BottomNavigationBarItem(
        icon: Icon(Icons.account_circle),
        label: 'Perfil',
      ),
    ];
  }

  Widget _page(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _profilePage() {
    // Prefer the live provider profile if available so updates reflect immediately
    final auth = Provider.of<AuthProvider>(context, listen: true);
    try {
      debugPrint(
        '[HomePage] _profilePage build — auth.profile photo=${auth.profile?['foto_url']?.toString() ?? '<none>'}',
      );
    } catch (_) {}
    final Map<String, dynamic> p = (auth.profile is Map<String, dynamic>)
        ? Map<String, dynamic>.from(auth.profile as Map)
        : (widget.profile is Map<String, dynamic>)
        ? Map<String, dynamic>.from(widget.profile as Map)
        : <String, dynamic>{};

    String pickString(List<String> keys) {
      for (final k in keys) {
        final v = p[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.trim().isNotEmpty) return s;
      }
      return '';
    }

    int pickInt(List<String> keys) {
      for (final k in keys) {
        final v = p[k];
        if (v == null) continue;
        if (v is int) return v;
        final s = v.toString();
        final parsed = int.tryParse(s);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    double pickDouble(List<String> keys) {
      for (final k in keys) {
        final v = p[k];
        if (v == null) continue;
        if (v is double) return v;
        if (v is int) return v.toDouble();
        final s = v.toString();
        final parsed = double.tryParse(s);
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    final displayName = widget.displayName?.toString().trim().isNotEmpty == true
        ? widget.displayName!
        : pickString([
            'displayName',
            'display_name',
            'nombre',
            'user',
            'username',
            'email',
          ]);
    final roleCandidate = pickString(['rol', 'role', 'tipo']);
    final role = roleCandidate.isNotEmpty ? roleCandidate : widget.role;

    final email = pickString(['email', 'correo', 'mail']);
    final telefono = pickString([
      'telefono',
      'phone',
      'telefono_movil',
      'telefono_mobile',
    ]);
    final ubicacion = pickString(['ubicacion', 'direccion', 'location']);
    final contratos = pickInt(['n_contratos', 'nContratos', 'contratos']);
    // backend may not provide 'n_favoritos' — show n_abonos as a proxy or 0
    final favoritos = pickInt(['n_favoritos', 'nFavoritos']) > 0
        ? pickInt(['n_favoritos', 'nFavoritos'])
        : pickInt(['n_abonos', 'nAbonos']);
    final saldoAbonado = pickDouble(['saldo_abonado', 'saldoAbonado', 'saldo']);
    final ultimaActividad = pickString([
      'ultima_actividad',
      'ultimaActividad',
      'last_activity',
      'ultimaActividad',
    ]);
    final fotoUrl = pickString(['foto_url', 'photo_url', 'avatar', 'foto']);
    final estado = pickString(['estado', 'status']);
    final createdAt = pickString(['created_at', 'createdAt', 'created']);

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.maroon,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Avatar (remote if available) with border
                // Avatar (remote if available) with border
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipOval(
                    child: fotoUrl.isNotEmpty
                        ? (fotoUrl.startsWith('data:')
                              ? FutureBuilder<Uint8List>(
                                  future: compute(
                                    _decodeBase64ToBytes,
                                    fotoUrl.split(',').last,
                                  ),
                                  builder: (context, snap) {
                                    if (snap.connectionState ==
                                            ConnectionState.done &&
                                        snap.hasData) {
                                      return Image.memory(
                                        snap.data!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _avatarFallback(displayName),
                                      );
                                    }
                                    if (snap.hasError)
                                      return _avatarFallback(displayName);
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    );
                                  },
                                )
                              : Image.network(
                                  fotoUrl,
                                  fit: BoxFit.cover,
                                  // Small avatar — limit decoded size to reduce memory usage.
                                  cacheWidth:
                                      (72 *
                                              MediaQuery.of(
                                                context,
                                              ).devicePixelRatio)
                                          .round(),
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(displayName),
                                ))
                        : _avatarFallback(displayName),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Perfil',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayName.isNotEmpty ? displayName : 'Usuario',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            role,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          if (estado.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: estado.toLowerCase() == 'activo'
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                estado,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Miembro desde ${_formatDate(context, createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contact card
          StyledCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información de contacto',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _contactRow(Icons.email, 'Email', email),
                const SizedBox(height: 8),
                _contactRow(Icons.phone, 'Teléfono', telefono),
                const SizedBox(height: 8),
                _contactRow(Icons.location_on, 'Ubicación', ubicacion),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action menu
          StyledCard(
            child: Column(
              children: [
                _menuTile(
                  Icons.person,
                  'Datos personales',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileEdit()),
                  ),
                ),
                _menuTile(
                  Icons.lock,
                  'Cambiar contraseña',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
                _menuTile(
                  Icons.tune,
                  'Preferencias',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PreferencesPage()),
                  ),
                ),
                Divider(height: 1),
                _menuTile(
                  Icons.exit_to_app,
                  'Cerrar sesión',
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: StyledCard(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$contratos',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: isDarkTheme
                                    ? AppColors.tan
                                    : AppColors.maroon,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Contratos',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StyledCard(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$favoritos',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: isDarkTheme
                                    ? AppColors.tan
                                    : AppColors.maroon,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Favoritos',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Additional stats row: saldo and ultima actividad
          Row(
            children: [
              Expanded(
                child: StyledCard(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatCurrency(context, saldoAbonado),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: isDarkTheme
                                    ? AppColors.tan
                                    : AppColors.maroon,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Saldo abonado',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StyledCard(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ultimaActividad.isNotEmpty
                              ? _formatDate(context, ultimaActividad)
                              : '-',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: isDarkTheme
                                    ? AppColors.alabaster
                                    : AppColors.midnightBlue,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Última actividad',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
        TextStyle(fontWeight: FontWeight.w600);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeadingIcon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: LeadingIcon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final selectedColor = navTheme.selectedItemColor ?? AppColors.maroon;
    final unselectedColor =
        navTheme.unselectedItemColor ?? AppColors.mediumGray;
    final bgColor =
        navTheme.backgroundColor ??
        (isDark
            ? AppColors.midnightBlue.withAlpha((0.12 * 255).round())
            : Colors.white);

    final items = _buildItems(widget.role);

    // Determine which index corresponds to the MisResidencias page (if present)
    int residenciasIndex = -1;
    if (widget.role == 'propietario') residenciasIndex = 1;

    // Determine page count based on role
    final int pageCount = (widget.role == 'admin') ? 4 : 5;

    final isOnline = Provider.of<ConnectivityProvider>(context).isOnline;
    return Scaffold(
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Center(
                child: Text(
                  'Sin conexión a internet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _index = i);
              },
              itemBuilder: (context, i) => _pageForIndex(i, widget.role),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: bgColor,
        onTap: (i) async {
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
          setState(() => _index = i);
          if (i == residenciasIndex) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            try {
              auth.reloadResidencias();
            } catch (e) {
              debugPrint(
                '[HomePage] error reloading residencias via provider: $e',
              );
            }
          }
        },
      ),
    );
  }

  String _formatDate(BuildContext context, String input) {
    try {
      final dt = DateTime.tryParse(input);
      if (dt == null) return input;
      final locale = Localizations.localeOf(context).toString();
      final fmt = DateFormat.yMd(locale).add_Hm();
      return fmt.format(dt.toLocal());
    } catch (_) {
      return input;
    }
  }

  String _formatCurrency(BuildContext context, double value) {
    try {
      final locale = Localizations.localeOf(context).toString();
      final nf = NumberFormat.simpleCurrency(locale: locale, name: '\$');
      return nf.format(value);
    } catch (_) {
      return value.toString();
    }
  }
}
