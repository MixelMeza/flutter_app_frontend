import '../datasources/local/user_local_database.dart';

class UserRepositoryImpl {
  final UserLocalDatabase _localDb = UserLocalDatabase();

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _localDb.insertUser(user);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await _localDb.getAllUsers();
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    await _localDb.updateUser(user);
  }

  Future<void> deleteUser(int id) async {
    await _localDb.deleteUser(id);
  }
}
