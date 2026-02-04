import 'package:flutter/material.dart';

class DriversDashboard extends StatelessWidget {
  const DriversDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Drivers Dashboard")),
      body: const Center(child: Text("Drivers Content")),
    );
  }
}
