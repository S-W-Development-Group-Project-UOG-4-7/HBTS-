import 'package:flutter/material.dart';
import '../api/booking_api.dart';
import '../models/my_booking_item.dart';
import 'booking_details_page.dart';

<<<<<<< HEAD
class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});
=======
enum BookingStatusUI { scheduled, cancelled, onboard, completed }

BookingStatusUI mapUiStatus(MyBookingItem b) {
  final trip = b.tripStatus.toLowerCase().trim();
  final st = b.status.toLowerCase().trim();

  if (trip == "cancelled" || st == "cancelled") {
    return BookingStatusUI.cancelled;
  }

  if (trip == "completed") {
    return BookingStatusUI.completed;
  }

  // If passenger-side stale → show as completed
  if ((trip == "running" || trip == "started")) {
    final staleAt = b.arrivalTime.add(const Duration(hours: 24));
    if (DateTime.now().isAfter(staleAt)) {
      return BookingStatusUI.completed;
    }
    return BookingStatusUI.onboard;
  }

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
>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e

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
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
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

    final dt = item.departureTime.toLocal();
    final dateTimeText =
        "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} · ${_time(dt)}";

    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // leading icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.directions_bus_rounded),
            ),
            const SizedBox(width: 12),

            // main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.routeText,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: theme.hintColor),
                      const SizedBox(width: 6),
                      Text(dateTimeText, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniPill(text: "Seat: ${item.seatLabel}"),
                      // You can add more pills later: price, boarding stop, etc.
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(width: 10),
            _StatusBadge(status: uiStatus),
          ],
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

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
    );
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
        color: color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

