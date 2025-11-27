import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/entities/habitacion.dart';
import '../theme.dart';

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
  final PageController _recentesPageController = PageController(viewportFraction: 0.92);
  final PageController _favoritosPageController = PageController(viewportFraction: 0.92);
  final PageController _contratosPageController = PageController(viewportFraction: 0.94);

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
  List<dynamic> _combinedSearchResults = [];

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
      if (_currentRecentesPage != next) setState(() => _currentRecentesPage = next);
    });

    _favoritosPageController.addListener(() {
      final p = _favoritosPageController.page;
      if (p == null) return;
      final next = p.round();
      if (_currentFavoritosPage != next) setState(() => _currentFavoritosPage = next);
    });
    _contratosPageController.addListener(() {
      final p = _contratosPageController.page;
      if (p == null) return;
      final next = p.round();
      if (_currentContratosPage != next) setState(() => _currentContratosPage = next);
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
    // Minimal mock data so UI renders without external dependencies
    if (_habitacionesDestacadas.isEmpty) {
      _habitacionesDestacadas = [
        Habitacion(id: 1, nombre: 'Premium Suite', descripcion: 'Cómoda y amplia', precioMensual: 4500, residenciaId: 1, residenciaNombre: 'Residencia Central', imagenes: [], disponible: true, area: 20, capacidad: 1, tipo: 'individual', servicios: []),
        Habitacion(id: 2, nombre: 'Económica Plus', descripcion: 'A buen precio', precioMensual: 2500, residenciaId: 2, residenciaNombre: 'Residencia Norte', imagenes: [], disponible: true, area: 15, capacidad: 1, tipo: 'individual', servicios: []),
        Habitacion(id: 3, nombre: 'Loft Central', descripcion: 'Ideal para estudiantes', precioMensual: 3200, residenciaId: 1, residenciaNombre: 'Residencia Central', imagenes: [], disponible: true, area: 18, capacidad: 1, tipo: 'loft', servicios: []),
      ];
    }

    if (_vistoRecientemente.isEmpty) {
      _vistoRecientemente = [
        {'id': 1, 'nombre': 'Suite Premium', 'precio': 4500.0, 'residencia': 'Residencia Central'},
        {'id': 2, 'nombre': 'Loft Central', 'precio': 3200.0, 'residencia': 'Residencia Central'},
      ];
    }

    if (_contratos.isEmpty) {
      _contratos = [
        {'id': 1, 'residencia': 'Residencia A', 'habitacion': '204', 'fechaInicio': '01/03/2024', 'fechaFin': '31/08/2025', 'monto': 3500.0, 'estado': 'activo'},
      ];
    }

    if (_favoritos.isEmpty) {
      _favoritos = [
        {'id': 1, 'nombre': 'Económica Plus', 'precio': 2500.0, 'residencia': 'Residencia Norte'},
        {'id': 2, 'nombre': 'Studio Sol', 'precio': 2800.0, 'residencia': 'Residencia Sur'},
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
      _searchResults = _habitacionesDestacadas.where((h) => h.nombre.toLowerCase().contains(lower)).toList();
    });
  }

  void _onHabitacionTap(Habitacion h) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seleccionada: ${h.nombre}')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: SafeArea(child: Center(child: CircularProgressIndicator())));
    }

    // Role-aware sections
    final isInquilino = widget.role == 'inquilino';
    // filter contratos to only show finalized
    final List<Map<String, dynamic>> finalizadosContratos = _contratos.where((c) => (c['estado'] ?? '').toString().toLowerCase() == 'finalizado').toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kWine,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bienvenido a LIVUP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            Text(isInquilino ? 'Inquilino' : 'Propietario', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              // (Destacados carousel and indicator moved into non-search branch)

              // If searching: show only the filtered habitaciones (hide the normal sections)
              if (_isSearching) ...[
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('Resultados de búsqueda', style: theme.textTheme.titleMedium?.copyWith(color: kWine, fontWeight: FontWeight.w700)))),
                if (_searchResults.isEmpty)
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text('No se encontraron habitaciones', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)))),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate((c, i) {
                    final Habitacion habitacion = _searchResults[i];
                    return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildHabitacionCardCompact(habitacion, theme, isDark));
                  }, childCount: _searchResults.length)),
                ),
              ] else ...[

              // Destacados header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Destacados', style: theme.textTheme.titleMedium?.copyWith(color: kWine, fontWeight: FontWeight.w700)),
                ),
              ),

              // Destacados carousel
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _carouselHeight,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _habitacionesDestacadas.length,
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: _buildHabitacionCardCarousel(_habitacionesDestacadas[i], theme, isDark),
                    ),
                  ),
                ),
              ),

              // Dots indicator for Destacados
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 32,
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(_habitacionesDestacadas.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentPage == i ? 12 : 8, height: 8, decoration: BoxDecoration(color: _currentPage == i ? kWine : Colors.grey, borderRadius: BorderRadius.circular(8))))),
                  ),
                ),
              ),

              // Visto recientemente
              SliverToBoxAdapter(
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text('Visto recientemente', style: theme.textTheme.titleMedium?.copyWith(color: kWine, fontWeight: FontWeight.w700))),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: _vistoHeight,
                  child: PageView.builder(
                    controller: _recentesPageController,
                    itemCount: _vistoRecientemente.length,
                    itemBuilder: (c, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), child: _buildVistoCard(_vistoRecientemente[i], theme, MediaQuery.of(context).size.width * 0.72)),
                  ),
                ),
              ),
              // Dots indicator for 'Visto recientemente'
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 32,
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(_vistoRecientemente.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentRecentesPage == i ? 12 : 8, height: 8, decoration: BoxDecoration(color: _currentRecentesPage == i ? kWine : Colors.grey, borderRadius: BorderRadius.circular(8))))),
                  ),
                ),
              ),

              // Role-specific: contratos (inquilino) or favoritos (propietario)
              if (isInquilino) ...[
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('Historial de contratos', style: theme.textTheme.titleMedium?.copyWith(color: kWine, fontWeight: FontWeight.w700)))),
                // Show only finalized contracts. If none, show a message.
                if (finalizadosContratos.isEmpty) ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text('No hay contratos finalizados', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)))),
                ] else ...[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _contratosHeight,
                      child: PageView.builder(
                        controller: _contratosPageController,
                        itemCount: finalizadosContratos.length,
                        itemBuilder: (c, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), child: _buildContratoCardHorizontal(finalizadosContratos[i], theme, MediaQuery.of(context).size.width * 0.86)),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 28, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(finalizadosContratos.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentContratosPage == i ? 12 : 8, height: 8, decoration: BoxDecoration(color: _currentContratosPage == i ? kWine : Colors.grey, borderRadius: BorderRadius.circular(8)))))) ),
                  ),
                ],
              ] else ...[
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('Favoritos', style: theme.textTheme.titleMedium?.copyWith(color: kWine, fontWeight: FontWeight.w700)))),
                SliverToBoxAdapter(child: SizedBox(
                  height: _vistoHeight,
                  child: PageView.builder(
                    controller: _favoritosPageController,
                    itemCount: _favoritos.length,
                    itemBuilder: (c, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), child: _buildVistoCard(_favoritos[i], theme, MediaQuery.of(context).size.width * 0.72)),
                  ),
                )),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(_favoritos.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentFavoritosPage == i ? 12 : 8, height: 8, decoration: BoxDecoration(color: _currentFavoritosPage == i ? kWine : Colors.grey, borderRadius: BorderRadius.circular(8))))),
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

  Widget _buildHabitacionCardCompact(Habitacion habitacion, ThemeData theme, bool isDark) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  child: Icon(Icons.home_rounded, size: 36, color: AppColors.tan),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: habitacion.disponible 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            habitacion.disponible ? 'Disponible' : 'Ocupado',
                            style: TextStyle(
                              color: habitacion.disponible ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  Widget _buildHabitacionCardCarousel(Habitacion habitacion, ThemeData theme, bool isDark) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    // Compact fixed-height card to avoid bottom overflow in PageView
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.kBorderRadius)),
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
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppTheme.kBorderRadius), topRight: Radius.circular(AppTheme.kBorderRadius)),
                child: Container(
                  height: (_carouselHeight - 12) * 0.56,
                  width: double.infinity,
                  color: AppColors.midnightBlue.withOpacity(0.06),
                  child: const Center(child: Icon(Icons.home, size: 56, color: AppColors.tan)),
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
                            Text(habitacion.nombre, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(habitacion.residenciaNombre ?? '', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mediumGray), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatter.format(habitacion.precioMensual), style: theme.textTheme.titleMedium?.copyWith(color: AppColors.maroon, fontWeight: FontWeight.bold)),
                        Text('/mes', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.maroon)),
                      ]),
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

  Widget _buildContratoCard(Map<String, dynamic> contrato, ThemeData theme) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final bool isActivo = contrato['estado'] == 'activo';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Ver detalles del contrato
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ver contrato: ${contrato['residencia']}')),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nombre y badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      contrato['residencia'],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.midnightBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActivo ? Colors.green : AppColors.mediumGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActivo ? 'Activo' : 'Finalizado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Habitación
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.mediumGray),
                  const SizedBox(width: 4),
                  Text(
                    contrato['habitacion'],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Fechas
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.mediumGray),
                  const SizedBox(width: 4),
                  Text(
                    '${contrato['fechaInicio']} - ${contrato['fechaFin']}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Monto
              Row(
                children: [
                  Icon(Icons.attach_money, size: 18, color: AppColors.maroon),
                  const SizedBox(width: 4),
                  Text(
                    '${formatter.format(contrato['monto'])}/mes',
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

  Widget _buildContratoCardHorizontal(Map<String, dynamic> contrato, ThemeData theme, double width) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final bool isActivo = contrato['estado'] == 'activo';
    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(contrato['residencia'] ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isActivo ? Colors.green : AppColors.mediumGray, borderRadius: BorderRadius.circular(12)), child: Text(isActivo ? 'Activo' : 'Finalizado', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))),
            ]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.location_on, size: 14, color: AppColors.mediumGray), const SizedBox(width: 6), Text('Habitación ${contrato['habitacion'] ?? ''}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mediumGray))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.calendar_today, size: 14, color: AppColors.mediumGray), const SizedBox(width: 6), Text('${contrato['fechaInicio']} - ${contrato['fechaFin']}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mediumGray))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.attach_money, size: 16, color: AppColors.maroon), const SizedBox(width: 6), Text('${formatter.format(contrato['monto'] ?? 0)}/mes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.maroon))]),
          ]),
        ),
      ),
    );
  }

  Widget _buildVistoCard(Map<String, dynamic> item, ThemeData theme, double width) {
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
                Container(width: width * 0.36, height: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))), child: const Center(child: Icon(Icons.home, size: 36, color: AppColors.tan))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(item['nombre'] ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('${f.format(item['precio'] ?? 0)}/mes', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.maroon)),
                    ]),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
