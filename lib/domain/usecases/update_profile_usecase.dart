import '../repositories/auth_repository.dart';

class UpdateProfileUseCase {
  final AuthRepository repository;
  UpdateProfileUseCase(this.repository);

  Future<Map<String, dynamic>> call(Map<String, dynamic> updates) async {
    return await repository.updateProfile(updates);
  }
}
