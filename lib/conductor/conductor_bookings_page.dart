import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/conductor_store.dart';
import '../app_routes.dart';

class ConductorBookingsPage extends StatefulWidget {
  final int tripId;
  const ConductorBookingsPage({super.key, required this.tripId});

  @override
  State<ConductorBookingsPage> createState() => _ConductorBookingsPageState();
}

class _ConductorBookingsPageState extends State<ConductorBookingsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConductorStore>().loadTripBookings(widget.tripId);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(ConductorStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      store.setBookingSearch(_search.text);
      store.loadTripBookings(widget.tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConductorStore>();
    final hasTrip = widget.tripId > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bookings"),
        actions: [
          IconButton(
            onPressed: () async {
              await store.refreshActiveTrip();
              await store.loadTripBookings(widget.tripId);
            },
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: !hasTrip
          ? const Center(child: Text("No active trip. Start a trip to view bookings."))
          : RefreshIndicator(
              onRefresh: () => store.loadTripBookings(widget.tripId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => _onSearchChanged(store),
                    decoration: InputDecoration(
                      hintText: "Search booking id, seat, phone…",
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(store, "all", "All"),
                        _chip(store, "not_boarded", "Not boarded"),
                        _chip(store, "boarded", "Boarded"),
                        _chip(store, "cash_pending", "Cash pending"),
                        _chip(store, "paid", "Paid"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...store.tripBookings.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _bookingCard(context, b),
                      )),
                  if (store.tripBookings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: Text("No bookings found.")),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _chip(ConductorStore store, String value, String label) {
    final selected = store.bookingFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) {
          store.setBookingFilter(value);
          store.loadTripBookings(widget.tripId);
        },
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _bookingCard(BuildContext context, dynamic b) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          child: Text(b.seatNumber, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        title: Text(b.passengerName.isEmpty ? "Passenger" : b.passengerName,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text("${b.boardingStopName} → ${b.droppingStopName}"),
        trailing: const Icon(Icons.chevron_right_rounded),
onTap: () => Navigator.pushNamed(
  context,
  AppRoutes.conductorBookingDetails ?? '',
  arguments: {"booking": b},
),
      ),
    );
  }
}
