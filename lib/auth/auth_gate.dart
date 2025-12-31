import 'package:flutter/material.dart';
import '../services/token_store.dart';
import '../app_routes.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final loggedIn = await TokenStore.isLoggedIn();
    final isAdmin = await TokenStore.isAdmin();

    if (!mounted) return;

    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }

    // if admin, you can route to an admin route if you add it
    if (isAdmin) {
      // Navigator.pushNamedAndRemoveUntil(context, AppRoutes.adminHome, (_) => false);
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
