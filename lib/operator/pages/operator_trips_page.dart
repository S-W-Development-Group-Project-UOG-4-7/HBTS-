import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorTripsPage extends StatefulWidget {
  const OperatorTripsPage({super.key});

  @override
  State<OperatorTripsPage> createState() => _OperatorTripsPageState();
}

class _OperatorTripsPageState extends State<OperatorTripsPage> {
  late Future<List<Map<String, dynamic>>> _tripsFuture;
  String _statusFilter = "all";
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _tripsFuture = OperatorApi.fetchAssignedTrips(
      from: _range?.start,
      to: _range?.end,
    );
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == "delayed") {
      return Colors.orange.shade700;
    }
    if (normalized == "parked") {
      return Colors.blueGrey.shade700;
    }
    if (["ongoing", "running", "in_progress"].contains(normalized)) {
      return Colors.orange.shade700;
    }
    if (normalized == "completed") {
      return Colors.green.shade700;
    }
    if (normalized == "cancelled") {
      return Colors.red.shade600;
    }
    return Colors.blue.shade600;
  }

  List<Map<String, dynamic>> _applyStatusFilter(List<Map<String, dynamic>> trips) {
    if (_statusFilter == "all") return trips;
    return trips.where((trip) {
      final status = _safeStr(trip["status"]).toLowerCase();
      if (_statusFilter == "ongoing") {
        return ["ongoing", "running", "in_progress"].contains(status);
      }
      return status == _statusFilter;
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initial,
    );

    if (picked == null) return;

    setState(() {
      _range = picked;
      _loadData();
    });
  }

  void _clearRange() {
    setState(() {
      _range = null;
      _loadData();
    });
  }

  String _rangeLabel() {
    if (_range == null) return "All dates";
    final start = _range!.start.toIso8601String().split("T").first;
    final end = _range!.end.toIso8601String().split("T").first;
    return "$start to $end";
  }

  @override
  Widget build(BuildContext context) {
    final filters = const [
      {"id": "all", "label": "All"},
      {"id": "scheduled", "label": "Scheduled"},
      {"id": "delayed", "label": "Delayed"},
      {"id": "parked", "label": "Parked"},
      {"id": "ongoing", "label": "Ongoing"},
      {"id": "completed", "label": "Completed"},
      {"id": "cancelled", "label": "Cancelled"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trips and Status"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters.map((f) {
                final id = f["id"]!;
                return ChoiceChip(
                  label: Text(f["label"]!),
                  selected: _statusFilter == id,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = id;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Date range: ${_rangeLabel()}",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                TextButton(
                  onPressed: _pickRange,
                  child: const Text("Pick Range"),
                ),
                if (_range != null)
                  TextButton(
                    onPressed: _clearRange,
                    child: const Text("Clear"),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _tripsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  final trips = _applyStatusFilter(snapshot.data ?? []);
                  if (trips.isEmpty) {
                    return const Center(child: Text("No trips found."));
                  }

                  return ListView.builder(
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final tripId = _safeStr(trip["trip_id"]);
                      final routeName = _safeStr(trip["route_name"]);
                      final from = _safeStr(trip["from_location"]);
                      final to = _safeStr(trip["to_location"]);
                      final status = _safeStr(trip["status"]);
                      final bus = _safeStr(trip["license_plate_no"]);
                      final driver = _safeStr(trip["driver_name"]);
                      final date = _safeStr(trip["trip_date"]);
                      final depart = _safeStr(trip["departure_time"]);
                      final arrive = _safeStr(trip["arrival_time"]);
                      final seatsAvailable = _safeStr(trip["seats_available"]);
                      final seatsTotal = _safeStr(trip["seat_capacity"]);
                      final fare = _safeStr(trip["fare"]);

                      final title = routeName != "-"
                          ? routeName
                          : ((from != "-" || to != "-") ? "$from -> $to" : "Trip #$tripId");

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.directions_bus, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Date: $date | Depart: $depart | Arrive: $arrive",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Bus: $bus | Driver: $driver",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Seats: $seatsAvailable / $seatsTotal | Fare: $fare",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
