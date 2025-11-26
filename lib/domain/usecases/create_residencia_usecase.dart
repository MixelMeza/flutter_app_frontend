import '../entities/residencia.dart';
import '../repositories/residencia_repository.dart';

class CreateResidenciaUseCase {
  final ResidenciaRepository repository;
  CreateResidenciaUseCase(this.repository);

  Future<Map<String, dynamic>> call(Residencia residencia, {String jwt = ''}) async {
    return repository.createResidencia(residencia, jwt: jwt);
  }
}
