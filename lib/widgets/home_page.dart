import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'explore_map.dart';
import 'profile_edit.dart';
import 'change_password.dart';
import 'preferences.dart';
import 'leading_icon.dart';
import 'styled_card.dart';

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
    Key? key,
    required this.onLogout,
    this.email,
    this.displayName,
    this.role = 'inquilino',
    this.profile,
    this.isDarkMode,
    this.onToggleTheme,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  List<Widget> _buildPages(String role) {
    // Simple pages. Replace 'Explorar' placeholder with actual ExploreMap widget.
    if (role == 'propietario') {
      return [
        const ExploreMap(),
        _page('Mis Residencias', Icons.apartment),
        _page('Principal', Icons.home),
        _page('Contratos', Icons.description),
        _profilePage(),
      ];
    }

    if (role == 'admin') {
      return [
        const ExploreMap(),
        _page('Residencias', Icons.apartment),
        _page('Usuarios', Icons.groups),
        _profilePage(),
      ];
    }

    // default inquilino
    return [
      const ExploreMap(),
      _page('Alquiler', Icons.key),
      _page('Principal', Icons.home),
      _page('Favoritos', Icons.favorite),
      _profilePage(),
    ];
  }

  List<BottomNavigationBarItem> _buildItems(String role) {
    if (role == 'propietario') {
      return [
        BottomNavigationBarItem(icon: Icon(Icons.travel_explore), label: 'Explorar'),
        BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Resid.'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Principal'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Contratos'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Perfil'),
      ];
    }

    if (role == 'admin') {
      return [
        BottomNavigationBarItem(icon: Icon(Icons.travel_explore), label: 'Explorar'),
        BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Residencias'),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Usuarios'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Perfil'),
      ];
    }

    return [
      BottomNavigationBarItem(icon: Icon(Icons.travel_explore), label: 'Explorar'),
      BottomNavigationBarItem(icon: Icon(Icons.key), label: 'Alquiler'),
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Principal'),
      BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
      BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Perfil'),
    ];
  }

  Widget _page(String title, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleLarge)]),
    );
  }

  Widget _profilePage() {
    // Prefer the live provider profile if available so updates reflect immediately
    final auth = Provider.of<AuthProvider>(context, listen: true);
    try {
      debugPrint('[HomePage] _profilePage build — auth.profile photo=' + (auth.profile?['foto_url']?.toString() ?? '<none>'));
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
      : pickString(['displayName', 'display_name', 'nombre', 'user', 'username', 'email']);
    final _roleCandidate = pickString(['rol', 'role', 'tipo']);
    final role = _roleCandidate.isNotEmpty ? _roleCandidate : widget.role;

    final email = pickString(['email', 'correo', 'mail']) ;
    final telefono = pickString(['telefono', 'phone', 'telefono_movil', 'telefono_mobile']);
    final ubicacion = pickString(['ubicacion', 'direccion', 'location']);
    final contratos = pickInt(['n_contratos', 'nContratos', 'contratos']);
    // backend may not provide 'n_favoritos' — show n_abonos as a proxy or 0
    final favoritos = pickInt(['n_favoritos', 'nFavoritos']) > 0 ? pickInt(['n_favoritos', 'nFavoritos']) : pickInt(['n_abonos', 'nAbonos']);
    final saldoAbonado = pickDouble(['saldo_abonado', 'saldoAbonado', 'saldo']) ;
    final ultimaActividad = pickString(['ultima_actividad', 'ultimaActividad', 'last_activity', 'ultimaActividad']);
    final fotoUrl = pickString(['foto_url', 'photo_url', 'avatar', 'foto']);
    final estado = pickString(['estado', 'status']);
    final createdAt = pickString(['created_at', 'createdAt', 'created']);

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
            child: Row(children: [
              // Avatar (remote if available) with border
                // Avatar (remote if available) with border
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
                  child: ClipOval(
                    child: fotoUrl.isNotEmpty
                        ? (fotoUrl.startsWith('data:')
                            ? Image.memory(
                                base64Decode(fotoUrl.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                            : Image.network(
                                fotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ))
                        : Center(
                            child: Text(
                            displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mi Perfil', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(displayName.isNotEmpty ? displayName : 'Usuario', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(role, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(width: 8),
                    if (estado.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: estado.toLowerCase() == 'activo' ? Colors.green.shade700 : Colors.grey.shade600, borderRadius: BorderRadius.circular(12)),
                        child: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ]),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Miembro desde ${_formatDate(context, createdAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ]
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Contact card
          StyledCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Información de contacto', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _contactRow(Icons.email, 'Email', email),
              const SizedBox(height: 8),
              _contactRow(Icons.phone, 'Teléfono', telefono),
              const SizedBox(height: 8),
              _contactRow(Icons.location_on, 'Ubicación', ubicacion),
            ]),
          ),

          const SizedBox(height: 16),

          // Action menu
          StyledCard(
            child: Column(children: [
              _menuTile(Icons.person, 'Datos personales', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileEdit()))),
              _menuTile(Icons.lock, 'Cambiar contraseña', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
              _menuTile(Icons.tune, 'Preferencias', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreferencesPage()))),
              Divider(height: 1),
              _menuTile(Icons.exit_to_app, 'Cerrar sesión', onTap: widget.onLogout),
            ]),
          ),

          const SizedBox(height: 16),

          // Stats cards
          Row(children: [
            Expanded(
              child: StyledCard(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$contratos', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.maroon, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Contratos', style: Theme.of(context).textTheme.bodyMedium),
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
                      Text('$favoritos', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.maroon, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Favoritos', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Additional stats row: saldo and ultima actividad
          Row(children: [
            Expanded(
              child: StyledCard(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${_formatCurrency(context, saldoAbonado)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.maroon, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Saldo abonado', style: Theme.of(context).textTheme.bodyMedium),
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
                        Text(ultimaActividad.isNotEmpty ? _formatDate(context, ultimaActividad) : '-', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.midnightBlue, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Última actividad', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ?? TextStyle(fontWeight: FontWeight.w600);

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LeadingIcon(icon, backgroundColor: AppColors.lightBlue.withAlpha((0.12 * 255).round())),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: labelStyle), const SizedBox(height: 4), Text(value, style: theme.textTheme.bodyMedium)])),
    ]);
  }

  Widget _menuTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: LeadingIcon(icon, backgroundColor: AppColors.tan.withAlpha((0.12 * 255).round())),
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
    final unselectedColor = navTheme.unselectedItemColor ?? AppColors.mediumGray;
    final bgColor = navTheme.backgroundColor ?? (isDark ? AppColors.midnightBlue.withAlpha((0.12 * 255).round()) : Colors.white);

    final pages = _buildPages(widget.role);
    final items = _buildItems(widget.role);

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: bgColor,
        onTap: (i) => setState(() => _index = i),
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

