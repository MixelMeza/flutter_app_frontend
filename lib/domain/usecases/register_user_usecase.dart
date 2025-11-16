import '../repositories/auth_repository.dart';

class RegisterUserUseCase {
  final AuthRepository repository;
  RegisterUserUseCase(this.repository);

  Future<Map<String, dynamic>> call(Map<String, dynamic> payload) async {
    return await repository.registerUser(payload);
  }
}
