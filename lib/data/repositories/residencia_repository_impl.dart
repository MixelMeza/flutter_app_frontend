import '../../domain/entities/residencia.dart';
import '../../domain/repositories/residencia_repository.dart';
import '../datasources/residencia_remote_data_source.dart';
import '../models/residencia_model.dart';
import '../../services/api_service.dart' as api_service;

class ResidenciaRepositoryImpl implements ResidenciaRepository {
  final ResidenciaRemoteDataSource remote;
  ResidenciaRepositoryImpl(this.remote);

  @override
  Future<Map<String, dynamic>> createResidencia(Residencia residencia, {String jwt = ''}) async {
    final model = ResidenciaModel(
      nombre: residencia.nombre,
      descripcion: residencia.descripcion,
      tipo: residencia.tipo,
      reglamentoUrl: residencia.reglamentoUrl,
      servicios: residencia.servicios,
      estado: residencia.estado,
      ubicacion: residencia.ubicacion,
      contacto: residencia.contacto,
      email: residencia.email,
      universidadId: residencia.universidadId,
    );
    final effectiveJwt = (jwt.isNotEmpty) ? jwt : (api_service.ApiService.authToken ?? '');
    return remote.createResidencia(model, jwt: effectiveJwt);
  }

  @override
  Future<List<Map<String, dynamic>>> getMyResidenciasSimple({String jwt = ''}) async {
    // Ensure in-memory token is loaded; if not, try loading from secure storage
    if ((jwt.isEmpty) && (api_service.ApiService.authToken == null)) {
      try {
        await api_service.ApiService.loadAuthToken();
      } catch (_) {}
    }
    final effectiveJwt = (jwt.isNotEmpty) ? jwt : (api_service.ApiService.authToken ?? '');
    return remote.getMyResidenciasSimple(jwt: effectiveJwt);
  }
}
