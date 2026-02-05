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

  if (!mounted) return;

  if (!loggedIn) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (_) => false,
    );
    return;
  }

  // ✅ role-based routing
  final role = await TokenStore.getRole();

  if (!mounted) return;

  if (role == "conductor") {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.conductorHome,
      (_) => false,
    );
    return;
  }

  if (role == "admin") {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.adminHome,
      (_) => false,
    );
    return;
  }

  // You can add operator/driver here later if needed
  Navigator.pushNamedAndRemoveUntil(
    context,
    AppRoutes.home,
    (_) => false,
  );
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}