import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../models/trip_model.dart';
import 'seat_selection_page.dart';

class TripDetailsArgs {
  final Trip trip;
  final int passengers;
  TripDetailsArgs({required this.trip, required this.passengers});
}

class TripDetailsPage extends StatelessWidget {
  final TripDetailsArgs args;
  const TripDetailsPage({super.key, required this.args});

  String _fmtTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final t = args.trip;
    final durMins = t.arrivalTime.difference(t.departureTime).inMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
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
                    t.routeName.isNotEmpty
                        ? t.routeName
                        : "${t.fromLocation} - ${t.toLocation}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text("${t.fromLocation} → ${t.toLocation}",
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Info(label: "Depart", value: _fmtTime(t.departureTime.toLocal())),
                      const SizedBox(width: 10),
                      _Info(label: "Arrive", value: _fmtTime(t.arrivalTime.toLocal())),
                      const SizedBox(width: 10),
                      _Info(label: "Type", value: t.serviceType),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Duration: ${durMins} mins", style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text("Capacity: ${t.capacity}",
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                  const SizedBox(height: 8),
                  Text("Status: ${t.status}", style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.seatSelect,
                  arguments: SeatSelectArgs(trip: t, passengers: args.passengers),
                );
              },
              icon: const Icon(Icons.event_seat),
              label: const Text("Select Seats",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
