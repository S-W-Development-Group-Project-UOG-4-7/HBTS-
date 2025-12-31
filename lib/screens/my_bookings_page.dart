import 'package:flutter/material.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: const Center(child: Text("Bookings list will be here")),
    );
  }
}
