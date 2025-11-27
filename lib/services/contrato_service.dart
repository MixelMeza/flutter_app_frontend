import 'api_service.dart';

class ContratoService {
  /// Fetch historial de contratos de un usuario por id
  static Future<List<dynamic>> historialByUsuarioId(int usuarioId) async {
    final dynamic data = await ApiService.get(
      '/api/contratos/historial/usuario/$usuarioId',
      token: ApiService.authToken,
    );
    if (data is List) return data;
    return List<dynamic>.from(data);
  }
}
