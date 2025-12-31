import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../services/token_store.dart';

class ProfilePage extends StatelessWidget {
  final ProfileArgs args;

  const ProfilePage({super.key, required this.args});

  Future<void> _logout(BuildContext context) async {
    await TokenStore.clear();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = args.photoUrl != null && args.photoUrl!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundImage: hasPhoto ? NetworkImage(args.photoUrl!) : null,
              child: !hasPhoto
                  ? Text(
                      args.name.isNotEmpty ? args.name[0].toUpperCase() : "U",
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(args.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text(args.email, style: TextStyle(color: Colors.grey.shade700))),
          const SizedBox(height: 18),

          _info("User ID", args.id),
          _info("Phone", args.phone ?? "-"),
          _info("Role", "Passenger"),

          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value),
      ),
    );
  }
}
