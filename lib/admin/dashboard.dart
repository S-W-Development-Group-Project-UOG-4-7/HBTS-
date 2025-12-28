import 'package:flutter/material.dart';
import '../services/token_store.dart';
import '/screens/login_page.dart';
import 'customers_dashboard.dart';
import 'drivers_dashboard.dart';
import 'operators_dashboard.dart';
import 'reports_dashboard.dart';


class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: TokenStore.isAdmin(),
      builder: (context, snapshot) {
        // ⏳ While checking role
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not admin or error → redirect
        if (!snapshot.hasData || snapshot.data != true) {
          Future.microtask(() {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          });

          return const Scaffold();
        }

        // ✅ ADMIN UI
        return Scaffold(
          appBar: AppBar(
            title: const Text("Admin Dashboard"),
            backgroundColor: Colors.blue.shade700,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await TokenStore.clear();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
             children: [
  _adminCard(
    context,
    Icons.people,
    "Customers",
    const CustomersDashboard(),
  ),
  _adminCard(
    context,
    Icons.directions_bus,
    "Drivers",
    const DriversDashboard(),
  ),
  _adminCard(
    context,
    Icons.support_agent,
    "Operators",
    const OperatorsDashboard(),
  ),

  _adminCard(
    context,
    Icons.analytics,
    "Reports",
    const ReportsDashboard(),
  ),
],

            ),
          ),
        );
      },
    );
  }

 Widget _adminCard(
  BuildContext context,
  IconData icon,
  String title,
  Widget page,
) {
  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    },
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.blue.shade700),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    ),
  );
}
}