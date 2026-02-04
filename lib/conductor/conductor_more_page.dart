import 'package:flutter/material.dart';
import '../services/token_store.dart';
import '../app_routes.dart';

class ConductorMorePage extends StatelessWidget {
  const ConductorMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("More")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_rounded),
              title: const Text("Offline Queue", style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text("Pending actions will sync automatically."),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.w900)),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w900)),
              onTap: () async {
                await TokenStore.clear();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
