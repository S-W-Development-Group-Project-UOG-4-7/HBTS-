import 'package:flutter/material.dart';
import '../app_routes.dart';


class BookingSuccessArgs {
  final String bookingId;
  BookingSuccessArgs({required this.bookingId});
}

class BookingSuccessPage extends StatelessWidget {
  final BookingSuccessArgs args;
  const BookingSuccessPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
                const SizedBox(height: 12),
                const Text("Booking Confirmed!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("Booking ID: ${args.bookingId}", style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
                    },
                    child: const Text("Go Home", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
