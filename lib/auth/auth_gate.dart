import 'package:flutter/material.dart';
import '../services/token_store.dart';
import '../app_routes.dart' as routes;

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
      routes.AppRoutes.login,
      (_) => false,
    );
    return;
  }

  // ✅ role-based routing
  final role = await TokenStore.getRole();

  if (!mounted) return;

  if (role == null) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routes.AppRoutes.login,
      (_) => false,
    );
    return;
  }

  final String roleValue = role;
  switch (roleValue) {
    case "conductor":
      Navigator.pushNamedAndRemoveUntil(
        context,
        routes.AppRoutes.conductorHome!,
        (_) => false,
      );
      return;
    case "admin":
      Navigator.pushNamedAndRemoveUntil(
        context,
        routes.AppRoutes.adminHome!,
        (_) => false,
      );
      return;
    default:
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          routes.AppRoutes.home,
          (_) => false,
        );
      }
  }
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
