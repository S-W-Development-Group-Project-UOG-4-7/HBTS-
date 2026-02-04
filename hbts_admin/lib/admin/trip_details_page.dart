import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'trip_form_page.dart';

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({super.key, required this.trip});

  final Map<String, dynamic> trip;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _trip;
  late final TabController _tabController;
  late Future<List<dynamic>> _stopsFuture;
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.trip);
    _tabController = TabController(length: 3, vsync: this);
    _stopsFuture = _loadStops();
    _historyFuture = _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadStops() async {
    final tripId = _tripId;
    if (tripId == null) return [];
    return await AdminApi.getTripStops(tripId);
  }

  Future<List<dynamic>> _loadHistory() async {
    final tripId = _tripId;
    if (tripId == null) return [];
    return await AdminApi.getTripLocationHistory(tripId);
  }

  int? get _tripId {
    final raw = _trip["trip_id"] ?? _trip["tripId"] ?? _trip["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  String _value(String key, {String fallback = "-"}) {
    final v = _trip[key];
    if (v == null || v.toString().trim().isEmpty) return fallback;
    return v.toString();
  }

  String _valueAny(List<String> keys, {String fallback = "-"}) {
    for (final key in keys) {
      final value = _value(key, fallback: "");
      if (value.trim().isNotEmpty) return value;
    }
    return fallback;
  }

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  void _applyTripUpdate(Map<String, dynamic> updated) {
    setState(() {
      _trip = {..._trip, ...updated};
      _stopsFuture = _loadStops();
      _historyFuture = _loadHistory();
    });
  }

  Future<void> _openAddStop() async {
    final tripId = _tripId;
    if (tripId == null) return;

    final stopIdCtrl = TextEditingController();
    final orderCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    bool boardingAllowed = true;
    List<Map<String, dynamic>> stops = [];
    int? selectedStopId;
    bool loadingStops = true;

    Future<void> pickTime(StateSetter setState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked == null) return;
      final hh = picked.hour.toString().padLeft(2, "0");
      final mm = picked.minute.toString().padLeft(2, "0");
      setState(() => timeCtrl.text = "$hh:$mm");
    }

    String? combineDateAndTime(String? dateRaw, String timeRaw) {
      final time = timeRaw.trim();
      if (time.isEmpty) return null;
      if (time.contains("-")) return time;

      String date = (dateRaw ?? "").trim();
      if (date.isEmpty) return time.length == 5 ? "$time:00" : time;

      if (date.contains("T")) {
        date = date.split("T").first;
      }

      final safeTime = time.length == 5 ? "$time:00" : time;
      return "$date $safeTime";
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> loadStopsOnce() async {
            if (!loadingStops) return;
            try {
              final data = await AdminApi.getStops();
              stops = data.cast<Map<String, dynamic>>();
            } catch (_) {
              stops = [];
            } finally {
              setState(() => loadingStops = false);
            }
          }

          loadStopsOnce();

          String stopLabel(Map<String, dynamic> stop) {
            final id = stop["stop_id"] ?? stop["id"] ?? "-";
            final name = stop["stop_name"] ?? stop["name"] ?? "Stop";
            final code = stop["stop_code"] ?? stop["code"];
            final city = stop["city"];
            final parts = <String>[
              name.toString(),
              if (code != null && code.toString().trim().isNotEmpty)
                code.toString(),
              if (city != null && city.toString().trim().isNotEmpty)
                city.toString(),
            ];
            return "${parts.join(" • ")} (ID: $id)";
          }

          return AlertDialog(
            title: const Text("Add Trip Stop"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loadingStops)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(),
                  ),
                DropdownButtonFormField<int?>(
                  value: selectedStopId,
                  items: stops
                      .map(
                        (s) => DropdownMenuItem<int?>(
                          value: _toInt(s["stop_id"] ?? s["id"]),
                          child: Text(stopLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedStopId = value;
                    stopIdCtrl.text = value?.toString() ?? "";
                    setState(() {});
                  },
                  decoration: const InputDecoration(labelText: "Stop"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Stop Order"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeCtrl,
                  readOnly: true,
                  onTap: () => pickTime(setState),
                  decoration: const InputDecoration(
                    labelText: "Scheduled Time",
                    hintText: "HH:MM",
                    suffixIcon: Icon(Icons.schedule),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Boarding Allowed"),
                  value: boardingAllowed,
                  onChanged: (value) => setState(() => boardingAllowed = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedStopId == null) return;
                  Navigator.pop(dialogContext, true);
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    try {
      final stopId = int.tryParse(stopIdCtrl.text.trim());
      if (stopId == null) {
        throw Exception("Stop ID is required");
      }
      final order = int.tryParse(orderCtrl.text.trim());
      final scheduledTime = combineDateAndTime(
        _trip["trip_date"]?.toString(),
        timeCtrl.text,
      );

      await AdminApi.addTripStop(tripId, {
        "stopId": stopId,
        if (order != null) "stopOrder": order,
        if (scheduledTime != null) "scheduledTime": scheduledTime,
        "isBoardingAllowed": boardingAllowed,
      });

      if (!mounted) return;
      setState(() {
        _stopsFuture = _loadStops();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip stop added")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripId = _valueAny(["trip_id", "tripId", "id"]);
    final routeName =
        _valueAny(["route_name", "routeName", "name"], fallback: _valueAny([
      "route_code",
      "route_no",
      "routeCode",
    ]));
    final plate =
        _valueAny(["license_plate_no", "license_plate", "plate_no"]);
    final driverName =
        _valueAny(["driver_name", "driverName", "full_name", "name"]);
    final tripDate = _formatDate(_trip["trip_date"] ?? _trip["tripDate"]);
    final departure =
        _formatTime(_trip["departure_time"] ?? _trip["departureTime"]);
    final arrival =
        _formatTime(_trip["arrival_time"] ?? _trip["arrivalTime"]);
    final status = _valueAny(["status"], fallback: "scheduled");
    final statusLabel = _statusLabel(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Details"),
            Tab(text: "Stops"),
            Tab(text: "Location"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeName.isEmpty ? "Trip $tripId" : routeName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(label: "Trip ID", value: tripId),
                        const SizedBox(height: 6),
                        _InfoRow(label: "Bus", value: plate),
                        const SizedBox(height: 6),
                        _InfoRow(label: "Driver", value: driverName),
                        const SizedBox(height: 6),
                        _InfoRow(label: "Date", value: tripDate),
                        const SizedBox(height: 6),
                        _InfoRow(label: "Depart", value: departure),
                        const SizedBox(height: 6),
                        _InfoRow(label: "Arrive", value: arrival),
                        const SizedBox(height: 6),
                        _InfoRow(label: "Status", value: statusLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TripFormPage(trip: _trip),
                          ),
                        );
                        if (!context.mounted) return;
                        if (result is Map<String, dynamic>) {
                          _applyTripUpdate(result);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Trip updated")),
                          );
                          return;
                        }
                        if (result == true) {
                          setState(() {
                            _stopsFuture = _loadStops();
                            _historyFuture = _loadHistory();
                          });
                        }
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Edit Trip"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<dynamic>>(
            future: _stopsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final stops = snapshot.data ?? [];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 34,
                        child: OutlinedButton.icon(
                          onPressed: _openAddStop,
                          icon: const Icon(Icons.add),
                          label: const Text("Add Stop"),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: stops.isEmpty
                        ? const Center(child: Text("No trip stops found"))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: stops.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final stop = stops[index] as Map<String, dynamic>;
                              final stopId =
                                  stop["stop_id"] ?? stop["stopId"] ?? stop["id"];
                              final name = stop["stop_name"] ??
                                  stop["stopName"] ??
                                  stop["name"] ??
                                  "Stop $stopId";
                              final code = stop["stop_code"] ??
                                  stop["stopCode"] ??
                                  stop["code"];
                              final order = stop["stop_order"] ??
                                  stop["stopOrder"] ??
                                  stop["order"];
                              final time = _formatDateTime(
                                stop["scheduled_time"] ?? stop["time"],
                              );
                              final boarding =
                                  stop["is_boarding_allowed"] == true;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${order ?? "-"}${order == null ? "" : "."} $name${code != null ? " ($code)" : ""}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text("Scheduled: $time"),
                                      Text(
                                          "Boarding: ${boarding ? "Yes" : "No"}"),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          FutureBuilder<List<dynamic>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text("No location history found"));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final item = items[index] as Map<String, dynamic>;
                  final lat =
                      (item["lat"] ?? item["latitude"] ?? item["lat_deg"])
                          ?.toString() ??
                          "-";
                  final lng =
                      (item["lng"] ?? item["longitude"] ?? item["lng_deg"])
                          ?.toString() ??
                          "-";
                  final speed = (item["speed"] ?? item["velocity"])
                          ?.toString() ??
                      "-";
                  final time = _formatDateTime(
                    item["recorded_at"] ?? item["recordedAt"] ?? item["time"],
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Lat: $lat, Lng: $lng",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text("Speed: $speed"),
                          Text("Time: $time"),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null) return "-";
  final raw = value.toString();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final y = parsed.year.toString().padLeft(4, "0");
  final m = parsed.month.toString().padLeft(2, "0");
  final d = parsed.day.toString().padLeft(2, "0");
  return "$y-$m-$d";
}

String _formatDateTime(dynamic value) {
  if (value == null) return "-";
  final raw = value.toString();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final y = parsed.year.toString().padLeft(4, "0");
  final m = parsed.month.toString().padLeft(2, "0");
  final d = parsed.day.toString().padLeft(2, "0");
  final h = parsed.hour.toString().padLeft(2, "0");
  final min = parsed.minute.toString().padLeft(2, "0");
  return "$y-$m-$d $h:$min";
}

String _formatTime(dynamic value) {
  if (value == null) return "-";
  final raw = value.toString().trim();
  if (raw.isEmpty) return "-";
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    final h = parsed.hour.toString().padLeft(2, "0");
    final m = parsed.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }
  if (raw.contains(" ")) {
    final parts = raw.split(" ");
    return _formatTime(parts.last);
  }
  if (raw.contains(":")) {
    final bits = raw.split(":");
    if (bits.length >= 2) {
      return "${bits[0].padLeft(2, "0")}:${bits[1].padLeft(2, "0")}";
    }
  }
  return raw;
}

String _statusLabel(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains("progress")) return "running";
  if (normalized.contains("cancel")) return "cancelled";
  return normalized.isEmpty ? "scheduled" : value;
}

