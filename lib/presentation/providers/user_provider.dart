import 'package:flutter/material.dart';
import '../../data/repositories/user_repository_impl.dart';

class UserProvider extends ChangeNotifier {
  final UserRepositoryImpl _userRepo = UserRepositoryImpl();

  List<Map<String, dynamic>> users = [];

  Future<void> loadUsers() async {
    users = await _userRepo.getAllUsers();
    notifyListeners();
  }

  Future<void> addUser(Map<String, dynamic> user) async {
    await _userRepo.saveUser(user);
    await loadUsers();
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    await _userRepo.updateUser(user);
    await loadUsers();
  }

  Future<void> deleteUser(int id) async {
    await _userRepo.deleteUser(id);
    await loadUsers();
  }
}
