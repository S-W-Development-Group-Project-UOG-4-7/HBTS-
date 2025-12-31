import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'auth/auth_gate.dart';

void main() {
  runApp(const HBTSApp());
}

class HBTSApp extends StatelessWidget {
  const HBTSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HBTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),

      // ✅ enables Navigator.pushNamed(...)
      onGenerateRoute: AppRoutes.onGenerate,

      // ✅ startup auth redirect happens inside AuthGate
      home: const AuthGate(),
    );
  }
}
