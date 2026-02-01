import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BookingQrPage extends StatelessWidget {
  final String qrText;

  const BookingQrPage({super.key, required this.qrText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking QR")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: qrText,
                size: 240,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                qrText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
