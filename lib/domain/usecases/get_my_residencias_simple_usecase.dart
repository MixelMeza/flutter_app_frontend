import '../repositories/residencia_repository.dart';

class GetMyResidenciasSimpleUseCase {
  final ResidenciaRepository repository;
  GetMyResidenciasSimpleUseCase(this.repository);

  Future<List<Map<String, dynamic>>> call({String jwt = ''}) async {
    return repository.getMyResidenciasSimple(jwt: jwt);
  }
}
