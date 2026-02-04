import 'package:flutter/material.dart';
import '../api/booking_api.dart';
import '../models/my_booking_item.dart';
import 'booking_details_page.dart';

class UpcomingTodayPage extends StatefulWidget {
  const UpcomingTodayPage({super.key});

  @override
  State<UpcomingTodayPage> createState() => _UpcomingTodayPageState();
}

class _UpcomingTodayPageState extends State<UpcomingTodayPage> {
  bool _loading = true;
  String? _error;
  List<MyBookingItem> _items = [];

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
      final all = await BookingApi.getMyBookings();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final filtered = all.where((b) {
        // Use local departure for day grouping and timing comparisons
        final localDep = b.departureTime.toLocal();
        final bDate = DateTime(localDep.year, localDep.month, localDep.day);
        if (bDate != today) return false;

        // Exclude cancelled/completed
        final trip = b.tripStatus.toLowerCase().trim();
        final st = b.status.toLowerCase().trim();
        if (trip == 'cancelled' || st == 'cancelled' || trip == 'completed') return false;

        // Only upcoming (departure in future, local)
        return localDep.isAfter(now);
      }).toList()
        ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

      setState(() => _items = filtered);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Today')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Failed to load bookings:\n$_error'),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 140),
                            Center(child: Text('No upcoming bookings for today')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 2),
                          itemBuilder: (context, i) {
                            final b = _items[i];
                            return _UpcomingBookingCard(
                              item: b,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BookingDetailsPage(item: b)),
                                );
                                await _load();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class _UpcomingBookingCard extends StatelessWidget {
  final MyBookingItem item;
  final VoidCallback onTap;

  const _UpcomingBookingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dt = item.departureTime.toLocal();
    final dateText =
        "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    final timeText = _time(dt);
    final blue = Colors.blue.shade700;
    final statusText = item.tripStatus;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [blue, Colors.blue.shade500]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.routeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  dateText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.schedule_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  timeText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event_seat_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  "Seat: ${item.seatLabel}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                const Text(
                  "View details ->",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime dt) {
    final h = dt.hour;
    final hh = (h % 12 == 0) ? 12 : (h % 12);
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    return "$hh:$mm $ampm";
  }
}
