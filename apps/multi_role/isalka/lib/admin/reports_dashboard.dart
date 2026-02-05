import 'package:flutter/material.dart';

class ReportsDashboard extends StatelessWidget {
  const ReportsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reports Dashboard")),
      body: const Center(child: Text("Reports Content")),
    );
  }
}
