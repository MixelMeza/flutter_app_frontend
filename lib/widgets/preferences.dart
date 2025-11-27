import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import 'leading_icon.dart';
import 'styled_card.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StyledCard(
            child: SwitchListTile(
              title: const Text('Modo oscuro'),
              subtitle: const Text('Activar tema oscuro en la aplicación'),
              value: auth.isDark,
              onChanged: (v) async {
                await auth.toggleTheme(v);
              },
              secondary: LeadingIcon(Icons.brightness_6),
            ),
          ),
          const SizedBox(height: 12),
          StyledCard(
            child: ListTile(
              leading: LeadingIcon(Icons.settings),
              title: const Text('Preferencias de la aplicación'),
              subtitle: const Text('Opciones adicionales próximamente'),
            ),
          ),
        ],
      ),
    );
  }
}
