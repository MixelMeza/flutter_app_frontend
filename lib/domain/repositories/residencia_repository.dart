import '../entities/residencia.dart';

abstract class ResidenciaRepository {
  /// Creates a residencia and returns the created object as Map (raw from API)
  Future<Map<String, dynamic>> createResidencia(Residencia residencia, {String jwt = ''});

  /// Fetch a simplified list of residencias belonging to the authenticated user.
  /// Returns a list of raw Maps as returned by the API.
  Future<List<Map<String, dynamic>>> getMyResidenciasSimple({String jwt = ''});

  /// Fetch a single residencia by its id. Returns the raw JSON map from the API.
  Future<Map<String, dynamic>> getResidenciaById(int id, {String jwt = ''});
}
