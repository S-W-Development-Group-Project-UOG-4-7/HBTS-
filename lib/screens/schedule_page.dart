import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../models/trip_model.dart';
import '../api/trip_api.dart';
import 'trip_details_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _fromCtrl = TextEditingController(text: "Colombo");
  final _toCtrl = TextEditingController(text: "Kandy");
  DateTime _date = DateTime.now();
  int _passengers = 1;

  bool _loading = false;
  List<Trip> _results = [];

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  String _minsToHrs(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return "${m}m";
    return "${h}h ${m}m";
  }

  Future<void> _search() async {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();

    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter From and To locations")),
      );
      return;
    }

    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final trips = await TripApi.searchTrips(from: from, to: to, date: _date);
      setState(() => _results = trips);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTrip(Trip trip) {
    Navigator.pushNamed(
      context,
      AppRoutes.tripDetails,
      arguments: TripDetailsArgs(trip: trip, passengers: _passengers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _fmtDate(_date);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SearchCard(
            fromCtrl: _fromCtrl,
            toCtrl: _toCtrl,
            dateLabel: dateLabel,
            passengers: _passengers,
            onPickDate: _pickDate,
            onPassengersChanged: (v) => setState(() => _passengers = v),
            onSwap: () {
              final tmp = _fromCtrl.text;
              _fromCtrl.text = _toCtrl.text;
              _toCtrl.text = tmp;
              setState(() {});
            },
            onSearch: _loading ? null : _search,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty)
            _EmptyState(
              title: "Search buses",
              subtitle: "Enter route and date to see available trips.",
              onQuickSearch: _search,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_results.length} trips found",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._results.map((t) {
                  final durMins = t.arrivalTime.difference(t.departureTime).inMinutes;
                  return _TripCard(
                    title: t.routeName.isNotEmpty
                        ? t.routeName
                        : "${t.fromLocation} - ${t.toLocation}",
                    subtitle: "${t.fromLocation} → ${t.toLocation}",
                    serviceType: t.serviceType,
                    depart: _fmtTime(t.departureTime),
                    arrive: _fmtTime(t.arrivalTime),
                    duration: _minsToHrs(durMins),
                    status: t.status,
                    capacity: t.capacity,
                    onTap: () => _openTrip(t),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final String dateLabel;
  final int passengers;

  final VoidCallback onPickDate;
  final ValueChanged<int> onPassengersChanged;
  final VoidCallback onSwap;
  final VoidCallback? onSearch;

  const _SearchCard({
    required this.fromCtrl,
    required this.toCtrl,
    required this.dateLabel,
    required this.passengers,
    required this.onPickDate,
    required this.onPassengersChanged,
    required this.onSwap,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromCtrl,
                    decoration: const InputDecoration(
                      labelText: "From",
                      prefixIcon: Icon(Icons.trip_origin),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: "Swap",
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_horiz),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: toCtrl,
                    decoration: const InputDecoration(
                      labelText: "To",
                      prefixIcon: Icon(Icons.place),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onPickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Date",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      child: Text(dateLabel),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Passengers",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: passengers,
                        items: List.generate(
                          6,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text("${i + 1}"),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) onPassengersChanged(v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search),
                label: const Text(
                  "Search Trips",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String serviceType;
  final String depart;
  final String arrive;
  final String duration;
  final String status;
  final int capacity;
  final VoidCallback onTap;

  const _TripCard({
    required this.title,
    required this.subtitle,
    required this.serviceType,
    required this.depart,
    required this.arrive,
    required this.duration,
    required this.status,
    required this.capacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text(
                      serviceType,
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _TimeChip(label: "Dep", value: depart),
                  const SizedBox(width: 8),
                  _TimeChip(label: "Arr", value: arrive),
                  const SizedBox(width: 8),
                  _TimeChip(label: "Dur", value: duration),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(subtitle, style: TextStyle(color: Colors.grey.shade700))),
                  Text(status, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Capacity: $capacity",
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;

  const _TimeChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text("$label: ", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onQuickSearch;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onQuickSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(Icons.directions_bus, size: 44, color: Colors.blue.shade700),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onQuickSearch,
                child: const Text("Try Search"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
