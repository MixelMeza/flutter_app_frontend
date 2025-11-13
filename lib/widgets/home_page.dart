import 'package:flutter/material.dart';
import '../theme.dart';
import 'explore_map.dart';

/// Role-aware HomePage with BottomNavigationBar.
/// Accepts a `role` string: 'inquilino', 'propietario', 'admin'.
class HomePage extends StatefulWidget {
  final VoidCallback onLogout;
  final String? email;
  final String? displayName;
  final Map<String, dynamic>? profile;
  final String role;

  const HomePage({Key? key, required this.onLogout, this.email, this.displayName, this.role = 'inquilino', this.profile}) : super(key: key);

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
        _page('Mis Residencias', Icons.home_work),
        _page('Principal', Icons.dashboard),
        _page('Contratos', Icons.assignment),
        _profilePage(),
      ];
    }

    if (role == 'admin') {
      return [
        const ExploreMap(),
        _page('Residencias', Icons.apartment),
        _page('Usuarios', Icons.group),
        _profilePage(),
      ];
    }

    // default inquilino
    return [
      const ExploreMap(),
      _page('Alquiler', Icons.book_online),
      _page('Principal', Icons.dashboard),
      _page('Favoritos', Icons.favorite_border),
      _profilePage(),
    ];
  }

  List<BottomNavigationBarItem> _buildItems(String role, Color selectedColor, Color unselectedColor) {
    if (role == 'propietario') {
      return [
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
        BottomNavigationBarItem(icon: Icon(Icons.home_work), label: 'Resid.'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Principal'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Contratos'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ];
    }

    if (role == 'admin') {
      return [
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
        BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Residencias'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Usuarios'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ];
    }

    return [
      BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
      BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Alquiler'),
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Principal'),
      BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Favoritos'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
    ];
  }

  Widget _page(String title, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleLarge)]),
    );
  }

  Widget _profilePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(radius: 44, backgroundColor: AppColors.midnightBlue, child: Icon(Icons.person, size: 44, color: AppColors.alabaster)),
          const SizedBox(height: 12),
          Text(widget.displayName ?? widget.email ?? 'Usuario', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          // show cached profile details when available (works offline)
          if (widget.profile != null) ...[
            Text(widget.profile!['email'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(widget.profile!['telefono'] ?? widget.profile!['phone'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(widget.profile!['direccion'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.exit_to_app), label: const Text('Cerrar sesión')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? AppColors.alabaster : AppColors.midnightBlue;
    final unselectedColor = isDark ? Colors.white54 : Colors.black45;

    final pages = _buildPages(widget.role);
    final items = _buildItems(widget.role, selectedColor, unselectedColor);

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: isDark ? AppColors.midnightBlue.withOpacity(0.12) : Colors.white,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

