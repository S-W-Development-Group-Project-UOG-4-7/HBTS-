import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/conductor_api.dart';
import '../state/conductor_store.dart';

class ConductorBookingDetailsPage extends StatefulWidget {
  final dynamic booking; // ConductorBooking
  const ConductorBookingDetailsPage({super.key, required this.booking});

  @override
  State<ConductorBookingDetailsPage> createState() => _ConductorBookingDetailsPageState();
}

class _ConductorBookingDetailsPageState extends State<ConductorBookingDetailsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConductorStore>();
    final b = widget.booking;
    final tripId = store.activeTrip?.tripId ?? b.tripId;

    return Scaffold(
      appBar: AppBar(title: const Text("Booking Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.blue.withOpacity(0.08),
                    ),
                    child: Text(b.seatNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.passengerName.isEmpty ? "Passenger" : b.passengerName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 6),
                      if ((b.passengerPhone ?? "").toString().isNotEmpty)
                        Text(b.passengerPhone.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text("Booking ID: ${b.bookingId}", style: const TextStyle(color: Colors.black54)),
                    ]),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Journey", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text("${b.boardingStopName} → ${b.droppingStopName}", style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text("Payment", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text("Paid via: ${b.paidVia}", style: const TextStyle(fontWeight: FontWeight.w700)),
                Text("Payment status: ${b.paymentStatus}", style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text("Boarding", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(b.isBoarded ? "Boarded ✅" : "Not boarded ❌", style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator())),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy || b.isBoarded
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ConductorApi.board(
                              bookingId: b.bookingId,
                              tripId: tripId,
                            );
                            await store.loadActiveTripBookings();
                            if (mounted) Navigator.pop(context);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text("Mark Boarded", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy || !b.isCashPending
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ConductorApi.payCash(
                              bookingId: b.bookingId,
                              tripId: tripId,
                              clientActionId: DateTime.now().microsecondsSinceEpoch.toString(),
                            );
                            await store.loadActiveTripBookings();
                            if (mounted) Navigator.pop(context);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text("Collect Cash", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
