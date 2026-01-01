import 'package:flutter/material.dart';

class TrackMyBookingPage extends StatelessWidget {
  const TrackMyBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track My Booking")),
      body: const Center(
        child: Text("Tracking by booking will be here"),
      ),
    );
  }
}
