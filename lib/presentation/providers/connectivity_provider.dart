import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// provider import not needed here; avoid using BuildContext
import '../../services/cache_service.dart';
import '../../di/locator.dart';
import '../../domain/usecases/update_profile_usecase.dart';
// auth_provider import not needed (we call usecase via locator)

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
      // Ejecutar sincronización en microtask sin depender de BuildContext
      Future.microtask(() async {
        try {
          // Buscar perfil local pendiente
          final localProfile = await CacheService.getProfile();
          if (localProfile != null && localProfile['pendingSync'] == true) {
            try {
              // Llamar al caso de uso directamente (evita dependencia de Provider/BuildContext)
              final usecase = locator<UpdateProfileUseCase>();
              // Sanitize local profile: remove internal flags before sending to server
              final sanitized = Map<String, dynamic>.from(localProfile);
              sanitized.remove('pendingSync');
              sanitized.remove('pendingAt');

              // Further sanitize: remove local-only data URIs (photo) before sending
              try {
                final foto = sanitized['foto_url'] as String?;
                if (foto != null && foto.startsWith('data:')) {
                  debugPrint('[ConnectivityProvider] Removing local data-uri foto before send');
                  sanitized.remove('foto_url');
                }
              } catch (_) {}

              // Call usecase with sanitized payload
              debugPrint('[ConnectivityProvider] Attempting to sync profile, payload keys: ${sanitized.keys.join(', ')}');
              final result = await usecase.call(sanitized);

              // Build profile to persist locally: prefer server response but keep local data-uri foto if present
              final Map<String, dynamic> toSave = Map<String, dynamic>.from(result);

              try {
                final localFoto = localProfile['foto_url'] as String?;
                if (localFoto != null && localFoto.startsWith('data:')) {
                  // preserve local data-uri image (was probably not uploaded by the server)
                  toSave['foto_url'] = localFoto;
                }
              } catch (_) {}

              // Ensure pending flags removed
              toSave.remove('pendingSync');
              toSave.remove('pendingAt');

              await CacheService.saveProfile(toSave);
              debugPrint('[ConnectivityProvider] Perfil sincronizado con el servidor');
            } catch (e) {
              debugPrint('[ConnectivityProvider] Falló sincronización automática: $e');
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
