import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Usuarios Offline')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: userProvider.users.length,
              itemBuilder: (context, index) {
                final user = userProvider.users[index];
                return ListTile(
                  title: Text(
                    user['displayName'] ?? user['nombre'] ?? 'Sin nombre',
                  ),
                  subtitle: Text(user['email'] ?? ''),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      if (user['id'] != null) {
                        userProvider.deleteUser(user['id']);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              child: Text('Agregar usuario de prueba'),
              onPressed: () async {
                await userProvider.addUser({
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'displayName': 'Nuevo Usuario',
                  'email': 'nuevo@ejemplo.com',
                  'telefono': '123456789',
                  'rol': 'inquilino',
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
