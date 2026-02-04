import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorBusStatsPage extends StatefulWidget {
  const OperatorBusStatsPage({super.key});

  @override
  State<OperatorBusStatsPage> createState() => _OperatorBusStatsPageState();
}

class _OperatorBusStatsPageState extends State<OperatorBusStatsPage> {
  late Future<List<Map<String, dynamic>>> _statsFuture;
  late DateTimeRange _range;
  String? _selectedBusId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(start: today, end: today);
    _loadData();
  }

  void _loadData() {
    _statsFuture = OperatorApi.fetchBusBookingCounts(
      from: _range.start,
      to: _range.end,
    );
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  String _busLabel(Map<String, dynamic> bus) {
    final busId = _safeStr(bus["bus_id"]);
    final plate = _safeStr(bus["license_plate_no"]);
    if (plate == "-" || plate.isEmpty) {
      return "Bus $busId";
    }
    return "Bus $busId - $plate";
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );

    if (picked == null) return;

    setState(() {
      _range = picked;
      _loadData();
    });
  }

  String _rangeLabel() {
    final start = _range.start.toIso8601String().split("T").first;
    final end = _range.end.toIso8601String().split("T").first;
    return "$start to $end";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Booking Status"),
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
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.directions_bus, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _statsFuture,
                            builder: (context, snapshot) {
                              final allBuses = snapshot.data ?? [];
                              final options = allBuses
                                  .map((b) => _safeStr(b["bus_id"]))
                                  .where((id) => id != "-")
                                  .toSet()
                                  .toList()
                                ..sort((a, b) => a.compareTo(b));

                              if (_selectedBusId != null && !options.contains(_selectedBusId)) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  setState(() {
                                    _selectedBusId = null;
                                  });
                                });
                              }

                              return DropdownButtonFormField<String>(
                                value: _selectedBusId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade100),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade100),
                                  ),
                                ),
                                hint: const Text("All buses"),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text("All buses"),
                                  ),
                                  ...options.map(
                                    (id) => DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(
                                        _busLabel(
                                          allBuses.firstWhere(
                                            (b) => _safeStr(b["bus_id"]) == id,
                                            orElse: () => {"bus_id": id},
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBusId = value;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: TextStyle(color: Colors.blueGrey.shade700),
                      ),
                    );
                  }

                  final allBuses = snapshot.data ?? [];
                  final scheduled = allBuses.where((bus) => _asInt(bus["trip_count"]) > 0).toList();
                  final filtered = _selectedBusId == null
                      ? scheduled
                      : allBuses
                          .where((bus) => _safeStr(bus["bus_id"]) == _selectedBusId)
                          .toList();

                  if (filtered.isEmpty) {
                    final message = _selectedBusId == null
                        ? "No buses scheduled for this range."
                        : "No data for the selected bus in this range.";
                    return Center(child: Text(message));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final bus = filtered[index];
                      final busId = _safeStr(bus["bus_id"]);
                      final plate = _safeStr(bus["license_plate_no"]);
                      final model = _safeStr(bus["model"]);
                      final capacity = _safeStr(bus["capacity"]);
                      final service = _safeStr(bus["service_type"]);
                      final tripCount = _asInt(bus["trip_count"]);
                      final online = _asInt(bus["online_booked"]);
                      final cash = _asInt(bus["cash_booked"]);
                      final cancelled = _asInt(bus["cancelled_booked"]);
                      final total = _asInt(bus["total_booked"]);

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
                              Text(
                                "Bus $busId - $plate",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Model: $model | Capacity: $capacity | Service: $service",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Booking Status",
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _statusPill("Trips", tripCount, Colors.blue.shade50, Colors.blue.shade700),
                                  _statusPill("Online", online, Colors.blue.shade100, Colors.blue.shade800),
                                  _statusPill("Cash", cash, Colors.blue.shade100, Colors.blue.shade700),
                                  _statusPill("Cancelled", cancelled, Colors.blueGrey.shade100, Colors.blueGrey.shade700),
                                  _statusPill("Total", total, Colors.blue.shade200, Colors.blue.shade900),
                                ],
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

  Widget _statusPill(String label, int value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
