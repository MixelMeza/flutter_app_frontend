import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/widgets/add_residencia_form.dart';
import '../services/api_service.dart';
import '../data/datasources/residencia_remote_data_source.dart';
import '../data/repositories/residencia_repository_impl.dart';
import '../domain/usecases/create_residencia_usecase.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'robust_image.dart';
import 'view_map.dart';
import '../presentation/widgets/residence_detail.dart';
// styled_card removed - not needed after stats deletion

// Small helper that avoids attempting network image loads when device
// has no network connectivity. This prevents repeated SocketException
// logs (DNS / failed host lookup) during development and on offline devices.
class _ResilientNetworkImage extends StatefulWidget {
  final String? url;
  final BoxFit fit;
  final double? height;

  const _ResilientNetworkImage({Key? key, required this.url, this.fit = BoxFit.cover, this.height}) : super(key: key);

  @override
  State<_ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<_ResilientNetworkImage> {
  bool? _hasNetwork;
  static bool? _globalHasNetwork;
  static DateTime? _globalHasNetworkCheckedAt;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      // Reuse a global short-lived cache to avoid many connectivity requests
      // when multiple cards build at once.
      final now = DateTime.now();
      if (_globalHasNetworkCheckedAt != null && _globalHasNetwork != null && now.difference(_globalHasNetworkCheckedAt!).inSeconds < 10) {
        setState(() {
          _hasNetwork = _globalHasNetwork;
        });
        return;
      }

      final conn = await Connectivity().checkConnectivity();
      final val = conn != ConnectivityResult.none;
      _globalHasNetwork = val;
      _globalHasNetworkCheckedAt = now;
      setState(() {
        _hasNetwork = val;
      });
    } catch (_) {
      _globalHasNetwork = false;
      _globalHasNetworkCheckedAt = DateTime.now();
      setState(() {
        _hasNetwork = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // While unknown, show a subtle loader background
    if (_hasNetwork == null) {
      return Container(color: AppColors.midnightBlue.withAlpha((0.04 * 255).round()), child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    if (_hasNetwork == false || widget.url == null || widget.url!.isEmpty) {
      return Container(color: AppColors.midnightBlue.withAlpha((0.06 * 255).round()), child: Center(child: Icon(Icons.apartment, size: 56, color: AppColors.tan)));
    }

    // device pixel ratio previously used to compute cacheWidth for Image.network.
    // RobustImage / CachedNetworkImage handles caching internally so we don't need it here.
    return RobustImage(
      source: widget.url,
      fit: widget.fit,
      height: widget.height,
    );
  }
}

class MisResidencias extends StatefulWidget {
  const MisResidencias({Key? key}) : super(key: key);

  @override
  State<MisResidencias> createState() => MisResidenciasState();
}

class MisResidenciasState extends State<MisResidencias> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  // `AuthProvider` is now the single source of truth for residencias.
  // This widget derives a local mapped view from `auth.myResidencias`.

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      // try int first, then double
      final i = int.tryParse(v);
      if (i != null) return i;
      final d = double.tryParse(v);
      if (d != null) return d.toInt();
    }
    if (v is num) return v.toInt();
    return 0;
  }

  // numeric helpers kept minimal; _toDouble not required currently

  // Extract a double from a dynamic map using several possible key names
  double? _extractDoubleFromMap(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        final val = m[k];
        if (val is num) return val.toDouble();
        if (val is String) {
          final d = double.tryParse(val);
          if (d != null) return d;
        }
      }
    }
    return null;
  }

  // Try multiple common names for latitude/longitude and return LatLng if found
  LatLng? _extractLatLng(dynamic loc) {
    if (loc == null) return null;
    if (loc is Map) {
      final lat = _extractDoubleFromMap(loc, ['lat', 'latitud', 'latitude', 'y']);
      final lng = _extractDoubleFromMap(loc, ['lng', 'lon', 'longitud', 'longitude', 'x']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }
  // (monthly data removed — stats panel deleted)

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If provider hasn't loaded residencias yet, trigger a load.
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.myResidencias.isEmpty) {
        // Don't await here; reloadResidencias handles its own state.
        auth.reloadResidencias();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Public method to allow external widgets (via GlobalKey) to trigger a reload.
  Future<void> reload() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.reloadResidencias();
  }

  // (removed _occupancyColor - not needed for card layout)

  Widget _buildHeader() {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: Text('Mis Residencias', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.alabaster : Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8, offset: const Offset(0,2))]),
              child: const Center(child: Icon(Icons.add, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStatsCards() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final mapped = auth.myResidencias.map<Map<String, dynamic>>((m) {
      return {
        'roomsOccupied': m['habitacionesOcupadas'] ?? m['roomsOccupied'] ?? 0,
        'roomsTotal': m['habitacionesTotales'] ?? m['roomsTotal'] ?? 0,
        'income': m['ingresos'] ?? m['income'] ?? 0,
      };
    }).toList();

    final totalResidencias = mapped.length;
    final availableCount = mapped.fold<int>(0, (a, e) {
      final roomsTotal = _toInt(e['roomsTotal']);
      final roomsOccupied = _toInt(e['roomsOccupied']);
      return a + (roomsTotal - roomsOccupied);
    });
    final totalIncome = mapped.fold<int>(0, (a, e) => a + _toInt(e['income']));
    final totalRooms = mapped.fold<int>(0, (a, e) => a + _toInt(e['roomsTotal']));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      {'icon': Icons.apartment, 'value': '$totalResidencias', 'label': 'Residencias', 'iconColor': isDark ? AppColors.iconOnDark : AppColors.maroon},
      {'icon': Icons.meeting_room, 'value': '$availableCount', 'label': 'Disponibles', 'iconColor': isDark ? AppColors.iconOnDark : Colors.green},
      {'icon': Icons.bed, 'value': '$totalRooms', 'label': 'Habitaciones', 'iconColor': isDark ? AppColors.iconOnDark : AppColors.midnightBlue},
      {'icon': Icons.attach_money, 'value': '\$${(totalIncome / 1000).round()}k', 'label': 'Ingresos', 'iconColor': isDark ? AppColors.iconOnDark : AppColors.lightBlue},
    ];

    final screenW = MediaQuery.of(context).size.width;
    final horizontalPadding = 16.0 * 2; // left + right padding
    const gap = 12.0;
    final available = screenW - horizontalPadding - gap * (items.length - 1);
    final cardWidth = (available / items.length).clamp(64.0, double.infinity);
    final cardHeight = screenW < 360 ? 78.0 : 92.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: List.generate(items.length * 2 - 1, (idx) {
        // interleave card, gap, card, gap ...
        if (idx.isOdd) return const SizedBox(width: gap);
        final i = idx ~/ 2;
        final it = items[i];
        return SizedBox(
          width: cardWidth,
          child: Container(
            height: cardHeight,
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withAlpha(24) : Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0,3))]),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(it['icon'] as IconData, color: it['iconColor'] as Color, size: 22),
              const SizedBox(height: 4),
              // Ensure numeric label always fits: use FittedBox
              FittedBox(fit: BoxFit.scaleDown, child: Text(it['value'].toString(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.alabaster : AppColors.midnightBlue, fontWeight: FontWeight.w800, fontSize: 20))),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text(it['label'].toString(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.alabaster.withAlpha((0.86*255).round()) : AppColors.midnightBlue, fontWeight: FontWeight.w600, fontSize: 12))),
            ]),
          ),
        );
      })),
    );
  }

  Widget _buildPropietarioEstadisticas() {
    return const SizedBox.shrink();
  }

  Widget _buildResidenciaCard(Map<String, dynamic> r) {
    // Replicate the reference card: rounded 16, shadow, image, badge, two metric boxes and action buttons
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        // fetch detail from API and open detail page
        final auth = Provider.of<AuthProvider>(context, listen: false);
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          final id = (r['id'] is int) ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
          await auth.getResidenciaById(id); // sigue actualizando el provider
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResidenceDetailPage(residenceId: id)));
        } catch (e) {
          try {
            Navigator.of(context).pop();
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando detalle: $e')));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color.fromRGBO(15, 65, 74, 0.08), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // image area
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: _ResilientNetworkImage(
                  url: r['image'] as String?,
                  fit: BoxFit.cover,
                  height: 160,
                ),
              ),
            ),
            if (_toInt(r['pending']) > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.group, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('${r['pending']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ),
          ]),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(r['title'] ?? r['nombre'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? AppColors.alabaster : Theme.of(context).textTheme.titleLarge?.color))),
                const SizedBox(width: 8),
                if (r['tipo'] != null)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text(r['tipo'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 16),

              // contact / email row (if provided)
              if (r['contacto'] != null || r['email'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    if (r['contacto'] != null) Expanded(child: Row(children: [const Icon(Icons.phone, size: 14, color: Colors.grey), const SizedBox(width: 6), Flexible(child: Text(r['contacto'].toString(), style: const TextStyle(fontSize: 13)))])),
                    if (r['email'] != null) Expanded(child: Row(children: [const Icon(Icons.email, size: 14, color: Colors.grey), const SizedBox(width: 6), Flexible(child: Text(r['email'].toString(), style: const TextStyle(fontSize: 13)))])),
                  ]),
                ),

              // metrics 2-column grid
              Row(children: [
                Expanded(
                  child: Builder(builder: (ctx) {
                    final isDarkTile = Theme.of(ctx).brightness == Brightness.dark;
                    final tileBg = isDarkTile ? const Color(0xFF373737) : AppColors.alabaster;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDarkTile ? [BoxShadow(color: Colors.black.withAlpha(28), blurRadius: 6, offset: const Offset(0, 2))] : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
                        border: isDarkTile ? Border.all(color: Colors.white.withOpacity(0.03)) : null,
                      ),
                      child: Builder(builder: (innerCtx) {
                        final labelColor = isDarkTile ? AppColors.alabaster.withOpacity(0.92) : AppColors.midnightBlue.withOpacity(0.9);
                        final valueColor = isDarkTile ? AppColors.alabaster : const Color(0xFF7F0303);
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Ocupadas', style: TextStyle(color: labelColor, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('${r['roomsOccupied']}/${r['roomsTotal']}', style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w700)),
                        ]);
                      }),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(builder: (ctx) {
                    final isDarkTile = Theme.of(ctx).brightness == Brightness.dark;
                    final tileBg = isDarkTile ? const Color(0xFF373737) : AppColors.alabaster;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDarkTile ? [BoxShadow(color: Colors.black.withAlpha(28), blurRadius: 6, offset: const Offset(0, 2))] : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
                        border: isDarkTile ? Border.all(color: Colors.white.withOpacity(0.03)) : null,
                      ),
                      child: Builder(builder: (innerCtx) {
                        final labelColor = isDarkTile ? AppColors.alabaster.withOpacity(0.92) : AppColors.midnightBlue.withOpacity(0.9);
                        final valueColor = isDarkTile ? AppColors.alabaster : const Color(0xFF10B981);
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Ingresos', style: TextStyle(color: labelColor, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('\$${r['income']}', style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w700)),
                        ]);
                      }),
                    );
                  }),
                ),
              ]),

              const SizedBox(height: 16),

              // actions list
              Column(children: [
                _flatAction('Ver habitaciones', trailing: Icons.chevron_right),
                const SizedBox(height: 8),
                _flatAction('Ver en mapa', trailing: Icons.map, onTap: () async {
                  final loc = r['ubicacion'];
                  final coords = _extractLatLng(loc);
                  if (coords != null) {
                    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewMap(initialPosition: coords, title: r['nombre'] ?? r['title'], ubicacion: loc)));
                    if (result == true) {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      try {
                        // Try to fetch the updated residencia detail and update local list
                        final updated = await auth.getResidenciaById(_toInt(r['id']));
                        if (updated.isNotEmpty) {
                          final ubic = updated['ubicacion'] ?? updated['ubicacion'];
                          if (ubic != null) {
                            await auth.updateResidenciaUbicacion(_toInt(r['id']), Map<String, dynamic>.from(ubic as Map));
                          } else {
                            await auth.reloadResidencias();
                          }
                        } else {
                          await auth.reloadResidencias();
                        }
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación actualizada')));
                      } catch (e) {
                        try { await auth.reloadResidencias(); } catch (_) {}
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación actualizada')));
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación no disponible')));
                  }
                }),
                const SizedBox(height: 8),
                _flatAction('Solicitudes pendientes', trailing: Icons.chevron_right, pending: _toInt(r['pending'])),
                const SizedBox(height: 8),
                _flatAction('Gastos', trailing: Icons.chevron_right),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // Flat full-width action used in the reference card
  Widget _flatAction(String label, {IconData? trailing, int? pending, VoidCallback? onTap}) {
    return Builder(builder: (ctx) {
      final isDarkTile = Theme.of(ctx).brightness == Brightness.dark;
      final bg = isDarkTile ? Theme.of(ctx).cardColor.withOpacity(0.96) : AppColors.alabaster;
      final textColor = isDarkTile ? AppColors.alabaster : AppColors.midnightBlue;
      final iconColor = isDarkTile ? AppColors.iconOnDark : AppColors.midnightBlue;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isDarkTile ? [BoxShadow(color: Colors.black.withAlpha(36), blurRadius: 6, offset: const Offset(0,2))] : null,
          border: isDarkTile ? Border.all(color: Colors.white.withOpacity(0.02)) : null,
        ),
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                if (pending != null && pending > 0) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20)), child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                ]
              ]),
              if (trailing != null) Icon(trailing, size: 20, color: iconColor),
            ]),
          ),
        ),
      );
    });
  }

  // direct loading moved to AuthProvider; widget calls `auth.reloadResidencias()` when needed

  Widget _buildAddCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).cardColor : AppColors.alabaster;
    final iconColor = isDark ? AppColors.alabaster : AppColors.maroon;
    final textColor = isDark ? AppColors.alabaster : AppColors.maroon;
    final borderColor = isDark ? Colors.white.withOpacity(0.03) : AppColors.maroon.withOpacity(0.12);

    return InkWell(
      onTap: () async {
        // Require login: ensure we have an auth token available
        final token = ApiService.authToken ?? '';
        if (token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para agregar una residencia')));
          return;
        }

        // Build clean-architecture pieces locally and open the form
        final baseUrl = 'http://10.0.2.2:8080';
        final remote = ResidenciaRemoteDataSource(baseUrl: baseUrl);
        final repo = ResidenciaRepositoryImpl(remote);
        final usecase = CreateResidenciaUseCase(repo);

        final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddResidenciaForm(createUseCase: usecase, jwt: token)));
        if (result != null && result is Map<String, dynamic>) {
          // Ask provider to refresh its list so UI stays consistent with server.
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.reloadResidencias();
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['nombre'] ?? 'Residencia'} añadida')));
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(alignment: Alignment.center, child: Icon(Icons.add, size: 28, color: iconColor)),
          const SizedBox(height: 12),
          Text(
            'Agregar nueva residencia',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              height: 1.05, // interline spacing tuned
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // Map provider residencias into the local display shape
    final mapped = auth.myResidencias.map<Map<String, dynamic>>((m) {
      return {
        'id': m['id'] ?? m['uuid'] ?? DateTime.now().millisecondsSinceEpoch,
        'title': m['nombre'] ?? '',
        'nombre': m['nombre'] ?? '',
        'image': m['imagen'] ?? m['image'] ?? 'assets/logo.png',
        'roomsOccupied': _toInt(m['habitacionesOcupadas'] ?? m['roomsOccupied']),
        'roomsTotal': _toInt(m['habitacionesTotales'] ?? m['roomsTotal']),
        'income': _toInt(m['ingresos'] ?? m['income']),
        'pending': _toInt(m['pending']),
        'contacto': m['contacto'],
        'email': m['email'],
        'occupancy': 0,
        'trendUp': true,
        'ubicacion': m['ubicacion'],
        'tipo': m['tipo'],
        'estado': m['estado'],
      };
    }).toList();

    Future<void> _onRefresh() async {
      await auth.reloadResidencias();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24, top: 6),
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildStatsCards(),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildPropietarioEstadisticas()),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: auth.loadingResidencias && mapped.isEmpty
                ? SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mapped.length + 1,
                    itemBuilder: (ctx, idx) {
                      if (idx < mapped.length) {
                        final r = mapped[idx];
                        return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildResidenciaCard(r));
                      }
                      return _buildAddCard();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

 
