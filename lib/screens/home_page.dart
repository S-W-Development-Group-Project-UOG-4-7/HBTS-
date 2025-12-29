import 'package:flutter/material.dart';
import '../services/token_store.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await TokenStore.isLoggedIn();
    final isAdmin = await TokenStore.isAdmin();

    if (!loggedIn) {
      _redirectToLogin();
      return;
    }

    // 🚫 Admin should not land on HomePage
    if (isAdmin) {
      _redirectToLogin();
      return;
    }

    if (mounted) {
      setState(() => _checkingAuth = false);
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("HBTS"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await TokenStore.clear();
              _redirectToLogin();
            },
          )
        ],
      ),
      body: const Center(
        child: Text(
          "Passenger Dashboard ✅",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
