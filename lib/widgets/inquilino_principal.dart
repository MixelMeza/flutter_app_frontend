import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/entities/habitacion.dart';
import '../theme.dart';
import '../services/habitacion_service.dart';
import '../services/api_service.dart';
import '../services/contrato_service.dart';
import '../services/cache_service.dart';

// Wine / deep red used for section accents
const Color kWine = Color(0xFF7B1F2F);

// Clean, single implementation of InquilinoPrincipal.
class InquilinoPrincipal extends StatefulWidget {
  final String role;
  const InquilinoPrincipal({Key? key, required this.role}) : super(key: key);

  @override
  State<InquilinoPrincipal> createState() => _InquilinoPrincipalState();
}

class _InquilinoPrincipalState extends State<InquilinoPrincipal> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.92);
  final PageController _recentesPageController = PageController(
    viewportFraction: 0.92,
  );
  final PageController _favoritosPageController = PageController(
    viewportFraction: 0.92,
  );
  final PageController _contratosPageController = PageController(
    viewportFraction: 0.94,
  );

  // layout constants to avoid overflow and keep consistent sizes
  // increased heights per request
  final double _carouselHeight = 260;
  final double _vistoHeight = 170;
  final double _contratosHeight = 170;

  int _currentPage = 0;
  int _currentRecentesPage = 0;
  int _currentFavoritosPage = 0;
  int _currentContratosPage = 0;

  bool _isLoading = true;
  bool _isSearching = false;

  List<Habitacion> _habitacionesDestacadas = [];
  List<Map<String, dynamic>> _vistoRecientemente = [];
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _favoritos = [];
  List<Habitacion> _searchResults = [];
  // unified generic search results (can contain Habitacion or Map entries from visto/favoritos)
  // List<dynamic> _combinedSearchResults = []; // unused

  @override
  void initState() {
    super.initState();
    _loadData();
    // keep UI updated for search clear button state
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _pageController.addListener(() {
      final p = _pageController.page;
      if (p == null) return;
      final next = p.round();
      if (_currentPage != next) setState(() => _currentPage = next);
    });

    _recentesPageController.addListener(() {
      final p = _recentesPageController.page;
      if (p == null) return;
      final next = p.round();
      if (_currentRecentesPage != next)
        setState(() => _currentRecentesPage = next);
    });

    _favoritosPageController.addListener(() {
      final p = _favoritosPageController.page;
      if (p == null) return;
      final next = p.round();
      if (_currentFavoritosPage != next)
        setState(() => _currentFavoritosPage = next);
    });
    _contratosPageController.addListener(() {
      final p = _contratosPageController.page;
      if (p == null) return;
      final next = p.round();
      if (_currentContratosPage != next)
        setState(() => _currentContratosPage = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _recentesPageController.dispose();
    _favoritosPageController.dispose();
    _contratosPageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 200));
    // Try loading destacados from backend; fall back to local mocks on error
    try {
      final fetched = await HabitacionService.fetchDestacados(limit: 20);
      if (fetched.isNotEmpty) {
        // Defensive: only keep habitaciones explicitly marked as destacado == true
        final filtered = fetched.where((h) => h.destacado == true).toList();
        _habitacionesDestacadas = filtered;
        debugPrint(
          '[InquilinoPrincipal] fetched ${fetched.length} habitaciones, ${filtered.length} destacados kept',
        );
      }
    } catch (e, st) {
      // Log the error so we can see why network fetch failed during runtime
      debugPrint('[InquilinoPrincipal] fetchDestacados error: $e');
      debugPrint('[InquilinoPrincipal] stack: $st');
      // Fall back to local mocks
      if (_habitacionesDestacadas.isEmpty) {
        _habitacionesDestacadas = [
          Habitacion(
            id: 1,
            nombre: 'Premium Suite',
            descripcion: 'Cómoda y amplia',
            precioMensual: 4500.0,
            residenciaId: 1,
            residenciaNombre: 'Residencia Central',
            imagenes: [],
            estado: 'disponible',
            destacado: true,
            capacidad: 1,
            piso: 2,
          ),
          // fallback mocks kept but only the first is destacado=true so only it will show in Destacados
          Habitacion(
            id: 2,
            nombre: 'Económica Plus',
            descripcion: 'A buen precio',
            precioMensual: 2500.0,
            residenciaId: 2,
            residenciaNombre: 'Residencia Norte',
            imagenes: [],
            estado: 'disponible',
            destacado: false,
            capacidad: 1,
            piso: 3,
          ),
          Habitacion(
            id: 3,
            nombre: 'Loft Central',
            descripcion: 'Ideal para estudiantes',
            precioMensual: 3200.0,
            residenciaId: 1,
            residenciaNombre: 'Residencia Central',
            imagenes: [],
            estado: 'ocupado',
            destacado: false,
            capacidad: 1,
            piso: 1,
          ),
        ];
      }
    }

    // If we fetched from network, log how many we got (helps debug backend connectivity)
    if (_habitacionesDestacadas.isNotEmpty) {
      debugPrint(
        '[InquilinoPrincipal] habitacionesDestacadas count: ${_habitacionesDestacadas.length}',
      );
    }

    // Try to load recent views from backend for authenticated users
    if (ApiService.authToken != null) {
      try {
        final recent = await HabitacionService.recentForMe(limit: 10);
        if (recent.isNotEmpty) {
          _vistoRecientemente = recent.map<Map<String, dynamic>>((r) {
            // r may be a view record that contains a nested 'habitacion' object,
            // or it could be the habitacion JSON itself. Normalize both cases.
            Map<String, dynamic> src = {};
            if (r is Map<String, dynamic>) {
              if (r['habitacion'] is Map) {
                src = Map<String, dynamic>.from(r['habitacion']);
              } else {
                src = Map<String, dynamic>.from(r);
              }
            }
            String nombre = '';
            double precio = 0.0;
            String residencia = '';
            // name fallbacks
            nombre =
                (src['nombre'] ??
                        src['titulo'] ??
                        src['codigo_habitacion'] ??
                        '')
                    .toString();
            // precio fallbacks and parsing
            dynamic p =
                src['precio_mensual'] ??
                src['precio'] ??
                src['precioMensual'] ??
                src['valor'] ??
                0;
            if (p is num) {
              precio = p.toDouble();
            } else if (p is String) {
              precio = double.tryParse(p.replaceAll(',', '')) ?? 0.0;
            }
            // residencia may be nested
            if (src['residencia'] is Map) {
              residencia = (src['residencia']['nombre'] ?? '').toString();
            } else {
              residencia = (src['residencia_nombre'] ?? src['residencia'] ?? '')
                  .toString();
            }
            return {
              'id': src['id'],
              'nombre': nombre,
              'precio': precio,
              'residencia': residencia,
            };
          }).toList();
        }
      } catch (e, st) {
        debugPrint('[InquilinoPrincipal] recentForMe error: $e');
        debugPrint('[InquilinoPrincipal] stack: $st');
        // fallback to local mock list if backend fails
        if (_vistoRecientemente.isEmpty) {
          _vistoRecientemente = [
            {
              'id': 1,
              'nombre': 'Suite Premium',
              'precio': 4500.0,
              'residencia': 'Residencia Central',
            },
            {
              'id': 2,
              'nombre': 'Loft Central',
              'precio': 3200.0,
              'residencia': 'Residencia Central',
            },
          ];
        }
      }
    } else {
      if (_vistoRecientemente.isEmpty) {
        _vistoRecientemente = [
          {
            'id': 1,
            'nombre': 'Suite Premium',
            'precio': 4500.0,
            'residencia': 'Residencia Central',
          },
          {
            'id': 2,
            'nombre': 'Loft Central',
            'precio': 3200.0,
            'residencia': 'Residencia Central',
          },
        ];
      }
    }

    if (_contratos.isEmpty) {
      // Try loading contratos from backend for authenticated user
      try {
        final profile = await CacheService.getProfile();
        int? uid;
        if (profile != null) {
          final possible =
              profile['id'] ??
              profile['usuarioId'] ??
              profile['userId'] ??
              profile['uid'];
          if (possible is int) uid = possible;
          if (possible is String) uid = int.tryParse(possible);
        }
        if (uid != null) {
          final fetched = await ContratoService.historialByUsuarioId(uid);
          if (fetched.isNotEmpty) {
            // keep as Map entries to reuse existing UI mapping
            _contratos = List<Map<String, dynamic>>.from(
              fetched.map((e) => Map<String, dynamic>.from(e)),
            );
          }
        }
      } catch (e, st) {
        debugPrint('[InquilinoPrincipal] fetchContratos error: $e');
        debugPrint('[InquilinoPrincipal] stack: $st');
      }

      // fallback mock if still empty
      if (_contratos.isEmpty) {
        _contratos = [
          {
            'id': 1,
            'residencia': 'Residencia A',
            'habitacion': '204',
            'fechaInicio': '01/03/2024',
            'fechaFin': '31/08/2025',
            'monto': 3500.0,
            'estado': 'finalizado',
          },
        ];
      }
    }

    if (_favoritos.isEmpty) {
      _favoritos = [
        {
          'id': 1,
          'nombre': 'Económica Plus',
          'precio': 2500.0,
          'residencia': 'Residencia Norte',
        },
        {
          'id': 2,
          'nombre': 'Studio Sol',
          'precio': 2800.0,
          'residencia': 'Residencia Sur',
        },
      ];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onSearchChanged(String q) {
    setState(() {
      // Only search habitaciones by name and show only those results
      _isSearching = q.isNotEmpty;
      if (q.isEmpty) {
        _searchResults = [];
        return;
      }
      final lower = q.toLowerCase();
      _searchResults = _habitacionesDestacadas
          .where((h) => h.nombre.toLowerCase().contains(lower))
          .toList();
    });
  }

  void _onHabitacionTap(Habitacion h) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Seleccionada: ${h.nombre}')));
    // Mark view in backend (associates view with authenticated user via token)
    // If you want anonymous sessions, pass a sessionUuid to HabitacionService.recordView
    HabitacionService.recordView(h.id ?? 0)
        .catchError((e) {
          debugPrint('[InquilinoPrincipal] recordView error: $e');
        })
        .then((_) async {
          // After recording view, refresh recents for authenticated user
          if (ApiService.authToken != null) {
            try {
              final recent = await HabitacionService.recentForMe(limit: 10);
              if (recent.isNotEmpty) {
                setState(() {
                  _vistoRecientemente = recent.map<Map<String, dynamic>>((r) {
                    Map<String, dynamic> src = {};
                    if (r is Map<String, dynamic>) {
                      if (r['habitacion'] is Map) {
                        src = Map<String, dynamic>.from(r['habitacion']);
                      } else {
                        src = Map<String, dynamic>.from(r);
                      }
                    }
                    final nombre =
                        (src['nombre'] ??
                                src['titulo'] ??
                                src['codigo_habitacion'] ??
                                '')
                            .toString();
                    dynamic p =
                        src['precio_mensual'] ??
                        src['precio'] ??
                        src['precioMensual'] ??
                        src['valor'] ??
                        0;
                    double precio = 0.0;
                    if (p is num) precio = p.toDouble();
                    if (p is String)
                      precio = double.tryParse(p.replaceAll(',', '')) ?? 0.0;
                    final residencia = src['residencia'] is Map
                        ? (src['residencia']['nombre'] ?? '').toString()
                        : (src['residencia_nombre'] ?? src['residencia'] ?? '')
                              .toString();
                    return {
                      'id': src['id'],
                      'nombre': nombre,
                      'precio': precio,
                      'residencia': residencia,
                    };
                  }).toList();
                });
              }
            } catch (e) {
              debugPrint(
                '[InquilinoPrincipal] refreshRecents after recordView failed: $e',
              );
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Role-aware sections
    final isInquilino = widget.role == 'inquilino';
    // Ensure we only show habitaciones explicitly marked as destacado
    final List<Habitacion> destacadosToShow = _habitacionesDestacadas
        .where((h) => h.destacado == true)
        .toList();
    // filter contratos to only show finalized
    final List<Map<String, dynamic>> finalizadosContratos = _contratos
        .where(
          (c) => (c['estado'] ?? '').toString().toLowerCase() == 'finalizado',
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kWine,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bienvenido a LIVUP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              isInquilino ? 'Inquilino' : 'Propietario',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Global search: visible for both inquilino and propietario
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchChanged,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          prefixIconColor: kWine,
                          hintText: 'Buscar habitaciones o residencias',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  color: Colors.black54,
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // (Destacados carousel and indicator moved into non-search branch)

              // If searching: show only the filtered habitaciones (hide the normal sections)
              if (_isSearching) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Resultados de búsqueda',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kWine,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (_searchResults.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'No se encontraron habitaciones',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((c, i) {
                      final Habitacion habitacion = _searchResults[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildHabitacionCardCompact(
                          habitacion,
                          theme,
                          isDark,
                        ),
                      );
                    }, childCount: _searchResults.length),
                  ),
                ),
              ] else ...[
                // Destacados header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Destacados',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kWine,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Destacados carousel
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _carouselHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: destacadosToShow.length,
                      itemBuilder: (c, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: _buildHabitacionCardCarousel(
                          destacadosToShow[i],
                          theme,
                          isDark,
                        ),
                      ),
                    ),
                  ),
                ),

                // Dots indicator for Destacados
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          destacadosToShow.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == i ? 12 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i ? kWine : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Visto recientemente
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Visto recientemente',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kWine,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _vistoHeight,
                    child: PageView.builder(
                      controller: _recentesPageController,
                      itemCount: _vistoRecientemente.length,
                      itemBuilder: (c, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: _buildVistoCard(
                          _vistoRecientemente[i],
                          theme,
                          MediaQuery.of(context).size.width * 0.72,
                        ),
                      ),
                    ),
                  ),
                ),
                // Dots indicator for 'Visto recientemente'
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _vistoRecientemente.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentRecentesPage == i ? 12 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentRecentesPage == i
                                  ? kWine
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Role-specific: contratos (inquilino) or favoritos (propietario)
                if (isInquilino) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Historial de contratos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: kWine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Show only finalized contracts. If none, show a message.
                  if (finalizadosContratos.isEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'No hay contratos finalizados',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: _contratosHeight,
                        child: PageView.builder(
                          controller: _contratosPageController,
                          itemCount: finalizadosContratos.length,
                          itemBuilder: (c, i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: _buildContratoCardHorizontal(
                              finalizadosContratos[i],
                              theme,
                              MediaQuery.of(context).size.width * 0.86,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 28,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              finalizadosContratos.length,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentContratosPage == i ? 12 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentContratosPage == i
                                      ? kWine
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Favoritos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: kWine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _vistoHeight,
                      child: PageView.builder(
                        controller: _favoritosPageController,
                        itemCount: _favoritos.length,
                        itemBuilder: (c, i) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: _buildVistoCard(
                            _favoritos[i],
                            theme,
                            MediaQuery.of(context).size.width * 0.72,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            _favoritos.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentFavoritosPage == i ? 12 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentFavoritosPage == i
                                    ? kWine
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitacionCardCompact(
    Habitacion habitacion,
    ThemeData theme,
    bool isDark,
  ) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _onHabitacionTap(habitacion),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen/Ícono
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.midnightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.home_rounded,
                    size: 36,
                    color: AppColors.tan,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habitacion.nombre,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.midnightBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (habitacion.residenciaNombre != null)
                      Row(
                        children: [
                          Icon(
                            Icons.apartment_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              habitacion.residenciaNombre!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Builder(
                          builder: (_) {
                            final disponible =
                                (habitacion.estado ?? 'disponible')
                                    .toString()
                                    .toLowerCase() !=
                                'ocupado';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: disponible
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                disponible ? 'Disponible' : 'Ocupado',
                                style: TextStyle(
                                  color: disponible ? Colors.green : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        Text(
                          formatter.format(habitacion.precioMensual),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.maroon,
                          ),
                        ),
                        Text(
                          '/mes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.maroon,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitacionCardCarousel(
    Habitacion habitacion,
    ThemeData theme,
    bool isDark,
  ) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    // Compact fixed-height card to avoid bottom overflow in PageView
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () => _onHabitacionTap(habitacion),
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
        child: SizedBox(
          height: _carouselHeight - 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.kBorderRadius),
                  topRight: Radius.circular(AppTheme.kBorderRadius),
                ),
                child: Container(
                  height: (_carouselHeight - 12) * 0.56,
                  width: double.infinity,
                  color: AppColors.midnightBlue.withOpacity(0.06),
                  child: const Center(
                    child: Icon(Icons.home, size: 56, color: AppColors.tan),
                  ),
                ),
              ),
              // Info row
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              habitacion.nombre,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              habitacion.residenciaNombre ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mediumGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatter.format(habitacion.precioMensual),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.maroon,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/mes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.maroon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildContratoCard method removed (unused - use _buildContratoCardHorizontal instead)

  Widget _buildContratoCardHorizontal(
    Map<String, dynamic> contrato,
    ThemeData theme,
    double width,
  ) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    String estadoRaw =
        (contrato['estado'] ??
                contrato['estadoContrato'] ??
                contrato['estado_contrato'] ??
                '')
            .toString();
    final bool isActivo =
        estadoRaw.toLowerCase() == 'activo' ||
        estadoRaw.toLowerCase() == 'vigente';
    final String estadoLabel = estadoRaw.isNotEmpty
        ? (estadoRaw[0].toUpperCase() + estadoRaw.substring(1).toLowerCase())
        : 'Finalizado';

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
      return 0.0;
    }

    final fechaInicio = parseDate(
      contrato['fechaInicio'] ?? contrato['fecha_inicio'],
    );
    final fechaFin = parseDate(contrato['fechaFin'] ?? contrato['fecha_fin']);
    final montoTotal = parseDouble(
      contrato['montoTotal'] ?? contrato['monto_total'] ?? contrato['monto'],
    );
    // final garantia = parseDouble(contrato['garantia']); // unused
    double montoMensual = 0.0;
    if (montoTotal > 0 && fechaInicio != null && fechaFin != null) {
      final months =
          (fechaFin.year - fechaInicio.year) * 12 +
          (fechaFin.month - fechaInicio.month);
      if (months > 0) montoMensual = montoTotal / months;
    }

    String habitacionLabel = contrato['habitacion']?.toString() ?? '';
    try {
      if (contrato['solicitud'] is Map) {
        final sol = Map<String, dynamic>.from(contrato['solicitud']);
        if (sol['habitacion'] is Map) {
          final h = Map<String, dynamic>.from(sol['habitacion']);
          habitacionLabel =
              (h['nombre'] ??
                      h['codigo_habitacion'] ??
                      h['codigo'] ??
                      h['titulo'] ??
                      '')
                  .toString();
        }
      }
    } catch (_) {}

    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      contrato['residencia'] ??
                          contrato['residencia_nombre'] ??
                          '',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActivo
                          ? Colors.green
                          : (estadoLabel.toLowerCase() == 'finalizado'
                                ? AppColors.mediumGray
                                : Colors.orange),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      estadoLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (habitacionLabel.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.mediumGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ' $habitacionLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    fechaInicio != null && fechaFin != null
                        ? '${DateFormat('dd/MM/yyyy').format(fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(fechaFin)}'
                        : '${contrato['fechaInicio'] ?? contrato['fecha_inicio'] ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: AppColors.maroon),
                  const SizedBox(width: 6),
                  Text(
                    montoMensual > 0
                        ? '${formatter.format(montoMensual)}/mes'
                        : (montoTotal > 0
                              ? '${formatter.format(montoTotal)} total'
                              : '\$0/mes'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.maroon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVistoCard(
    Map<String, dynamic> item,
    ThemeData theme,
    double width,
  ) {
    final f = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: _vistoHeight - 8,
            child: Row(
              children: [
                Container(
                  width: width * 0.36,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.home, size: 36, color: AppColors.tan),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['nombre'] ?? '',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${f.format(item['precio'] ?? 0)}/mes',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.maroon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
