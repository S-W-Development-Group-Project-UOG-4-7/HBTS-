import 'package:flutter/material.dart';

class OperatorsDashboard extends StatelessWidget {
  const OperatorsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Operators Dashboard")),
      body: const Center(child: Text("Operators Content")),
    );
  }
}
