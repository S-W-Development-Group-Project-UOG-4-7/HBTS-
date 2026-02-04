import 'package:flutter/material.dart';
import '../api/booking_api.dart';
import '../models/my_booking_item.dart';
import 'track_my_booking_page.dart';

class TrackMyBookingListPage extends StatefulWidget {
  const TrackMyBookingListPage({super.key});

  @override
  State<TrackMyBookingListPage> createState() => _TrackMyBookingListPageState();
}

class _TrackMyBookingListPageState extends State<TrackMyBookingListPage> {
  bool _loading = true;
  List<MyBookingItem> _current = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await BookingApi.getMyBookings();
      final current = all.where((b) => !b.isHistory).toList();

      if (!mounted) return;
      setState(() {
        _current = current;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track My Booking")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _current.isEmpty
              ? const SizedBox.shrink() // ✅ show nothing if no bookings
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _current.length,
                  itemBuilder: (_, i) {
                    final b = _current[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          b.routeText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Seat ${b.seatLabel} • ${_fmtDate(b.departureTime)}",
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrackMyBookingPage(bookingId: b.bookingId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  String _fmtDate(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "${dt.day}/${dt.month}/${dt.year} • $h:$m $ampm";
  }
}
