import 'package:flutter/material.dart';

class TrackBusPage extends StatelessWidget {
  const TrackBusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track a Bus")),
      body: const Center(
        child: Text("Tracking without booking will be here"),
      ),
    );
  }
}
