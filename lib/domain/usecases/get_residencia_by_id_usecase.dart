import '../repositories/residencia_repository.dart';

class GetResidenciaByIdUseCase {
  final ResidenciaRepository repository;
  GetResidenciaByIdUseCase(this.repository);

  Future<Map<String, dynamic>> call(int id, {String jwt = ''}) async {
    return repository.getResidenciaById(id, jwt: jwt);
  }
}
