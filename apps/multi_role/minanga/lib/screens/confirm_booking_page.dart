import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../api/booking_api.dart';
import '../models/trip_model.dart';
import 'booking_success_page.dart';

class ConfirmBookingArgs {
  final Trip trip;
  final List<int> seatIds; // seat_id list

  ConfirmBookingArgs({
    required this.trip,
    required this.seatIds,
  });
}

class ConfirmBookingPage extends StatefulWidget {
  final ConfirmBookingArgs args;
  const ConfirmBookingPage({super.key, required this.args});

  @override
  State<ConfirmBookingPage> createState() => _ConfirmBookingPageState();
}

class _ConfirmBookingPageState extends State<ConfirmBookingPage> {
  bool _loading = false;

  // TODO later: load from trip stops API
  int boardingStopId = 4; // Colombo
  int droppingStopId = 6; // Kandy

  String paidVia = "online"; // "online" | "cash"

  Future<void> _confirm() async {
    setState(() => _loading = true);

    try {
      int lastBookingId = -1;

      for (final seatId in widget.args.seatIds) {
        lastBookingId = await BookingApi.createBooking(
          tripId: widget.args.trip.id,
          seatId: seatId,
          boardingStopId: boardingStopId,
          droppingStopId: droppingStopId,
          paidVia: paidVia,
        );
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bookingSuccess,
        (_) => false,
        arguments: BookingSuccessArgs(bookingId: lastBookingId.toString()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.args.trip;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Booking"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.routeName.isNotEmpty ? t.routeName : "${t.fromLocation} - ${t.toLocation}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text("${t.fromLocation} → ${t.toLocation}",
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  Text(
                    "Seat IDs: ${widget.args.seatIds.join(", ")}",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: paidVia,
                    decoration: const InputDecoration(
                      labelText: "Payment method",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "online", child: Text("Online")),
                      DropdownMenuItem(value: "cash", child: Text("Cash")),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => paidVia = v ?? "online"),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    "Boarding stopId: $boardingStopId | Dropping stopId: $droppingStopId",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirm,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text(
                      "Confirm Booking",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
