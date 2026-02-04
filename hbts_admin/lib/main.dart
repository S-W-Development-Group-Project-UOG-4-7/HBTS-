import 'package:flutter/material.dart';

import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'admin/dashboard.dart';
import 'services/token_store.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HBTSApp());
}

class HBTSApp extends StatelessWidget {
  const HBTSApp({super.key});

  // Decide start screen based on saved role
  Future<Widget> _getStartPage() async {
    final role = await TokenStore.getRole();

    if (role == null) return const LoginScreen();
    if (role == "admin") return const AdminDashboard();

    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HBTS',
      debugShowCheckedModeBanner: false, // ✅ removes DEBUG banner
      theme: AppTheme.build(),
      home: FutureBuilder<Widget>(
        future: _getStartPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If anything fails, fallback to login
          if (snapshot.hasError || !snapshot.hasData) {
            return const LoginScreen();
          }

          return snapshot.data!;
        },
      ),
    );
  }
}
