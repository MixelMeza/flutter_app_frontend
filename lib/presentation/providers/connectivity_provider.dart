import '../../main.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../../services/cache_service.dart';
import 'auth_provider.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _init();
  }

  void _init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(ConnectivityResult result) async {
    final wasOffline = !_isOnline;
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();

    // Si acaba de volver la conexión, intenta sincronizar perfil local
    if (_isOnline && wasOffline) {
      // Necesitamos acceso al BuildContext para obtener el AuthProvider
      // Por simplicidad, usamos un Future.microtask para esperar a que el árbol esté listo
      Future.microtask(() async {
        try {
          // Buscar perfil local pendiente
          final localProfile = await CacheService.getProfile();
          if (localProfile != null && localProfile['pendingSync'] == true) {
            // Obtener el AuthProvider global
            final context = navigatorKey.currentContext;
            if (context != null) {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              // Intenta sincronizar con la API
              try {
                await auth.updateProfile(localProfile);
                // Si fue exitoso, limpiar flag de pendiente
                localProfile.remove('pendingSync');
                await CacheService.saveProfile(localProfile);
                // Opcional: mostrar mensaje
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil sincronizado con el servidor'), backgroundColor: Colors.green),
                );
              } catch (e) {
                // Si falla, dejar el flag para intentar después
                debugPrint('[ConnectivityProvider] Falló sincronización automática: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('[ConnectivityProvider] Error en sincronización automática: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
