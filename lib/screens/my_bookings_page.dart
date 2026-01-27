import 'package:flutter/material.dart';
import '../api/booking_api.dart';
import '../models/my_booking_item.dart';
import 'booking_details_page.dart';

enum BookingStatusUI { scheduled, cancelled, onboard, completed }

BookingStatusUI mapUiStatus(MyBookingItem b) {
  final trip = b.tripStatus.toLowerCase();
  final st = b.status.toLowerCase();

  if (trip == "cancelled" || st == "cancelled") return BookingStatusUI.cancelled;
  if (trip == "completed") return BookingStatusUI.completed;
  if (trip == "running" || trip == "started") return BookingStatusUI.onboard;

  return BookingStatusUI.scheduled;
}

class PassengerBookingsPage extends StatefulWidget {
  const PassengerBookingsPage({super.key});

  @override
  State<PassengerBookingsPage> createState() => _PassengerBookingsPageState();
}

class _PassengerBookingsPageState extends State<PassengerBookingsPage> {
  bool _loading = true;
  String? _error;
  List<MyBookingItem> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await BookingApi.getMyBookings();
      setState(() => _all = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _all.where((b) => !b.isHistory).toList();
    final history = _all.where((b) => b.isHistory).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Bookings"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Current Bookings"),
              Tab(text: "Booking History"),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Failed to load bookings:\n$_error"),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text("Retry")),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _BookingsList(items: current, onRefresh: _load),
                      _BookingsList(items: history, onRefresh: _load),
                    ],
                  ),
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<MyBookingItem> items;
  final Future<void> Function() onRefresh;

  const _BookingsList({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 140),
                Center(child: Text("No bookings found")),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final b = items[i];
                return _BookingCard(
                  item: b,
                  onTap: () async {
                    // refresh when coming back (seat changed / cancelled)
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BookingDetailsPage(item: b)),
                    );
                    await onRefresh();
                  },
                );
              },
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final MyBookingItem item;
  final VoidCallback onTap;

  const _BookingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uiStatus = mapUiStatus(item);

    final dt = item.departureTime;
    final dateTimeText =
        "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} · ${_time(dt)}";

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.routeText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(dateTimeText, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text("Seat: ${item.seatLabel}",
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _StatusBadge(status: uiStatus),
            ],
          ),
        ),
      ),
    );
  }

  String _time(DateTime dt) {
    final h = dt.hour;
    final hh = (h % 12 == 0) ? 12 : (h % 12);
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? "PM" : "AM";
    return "$hh:$mm $ampm";
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatusUI status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = {
      BookingStatusUI.scheduled: "Scheduled",
      BookingStatusUI.cancelled: "Cancelled",
      BookingStatusUI.onboard: "Passenger in Bus",
      BookingStatusUI.completed: "Completed",
    }[status]!;

    final color = {
      BookingStatusUI.scheduled: Colors.blue,
      BookingStatusUI.cancelled: Colors.red,
      BookingStatusUI.onboard: Colors.green,
      BookingStatusUI.completed: Colors.grey,
    }[status]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
