import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class TripFormPage extends StatefulWidget {
  const TripFormPage({super.key, this.trip});

  final Map<String, dynamic>? trip;

  @override
  State<TripFormPage> createState() => _TripFormPageState();
}

class _TripFormPageState extends State<TripFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _operatorIdCtrl = TextEditingController();
  final _tripDateCtrl = TextEditingController();
  final _departureCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _drivers = [];

  int? _selectedRouteId;
  int? _selectedBusId;
  int? _selectedDriverId;
  String _selectedStatus = "scheduled";

  int? get _tripId {
    final trip = widget.trip;
    if (trip == null) return null;
    final raw = trip["trip_id"] ?? trip["id"] ?? trip["tripId"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _seedFromTrip();
  }

  @override
  void dispose() {
    _operatorIdCtrl.dispose();
    _tripDateCtrl.dispose();
    _departureCtrl.dispose();
    _arrivalCtrl.dispose();
    super.dispose();
  }

  void _seedFromTrip() {
    final trip = widget.trip;
    if (trip == null) return;
    _selectedRouteId = _parseInt(trip["route_id"]);
    _selectedBusId = _parseInt(trip["bus_id"]);
    _selectedDriverId = _parseInt(trip["driver_id"]);
    _operatorIdCtrl.text = (trip["operator_id"] ?? "").toString();
    _tripDateCtrl.text = _formatDate(trip["trip_date"]);
    _departureCtrl.text = _formatTime(trip["departure_time"]);
    _arrivalCtrl.text = _formatTime(trip["arrival_time"]);
    final status = trip["status"]?.toString().trim();
    if (status != null && status.isNotEmpty) {
      final normalized = status.toLowerCase();
      _selectedStatus = _normalizeStatusForUi(normalized);
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _loading = true);
    try {
      final routes = await AdminApi.getRoutes();
      final buses = await AdminApi.getBuses();
      final drivers = await AdminApi.getAssignableDrivers();
      if (!mounted) return;
      setState(() {
        _routes = routes.cast<Map<String, dynamic>>();
        _buses = buses.cast<Map<String, dynamic>>();
        _drivers = drivers.cast<Map<String, dynamic>>();
        if (_selectedBusId != null) {
          _autoFillOperatorFromBus(_selectedBusId);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  int? _operatorIdForSelectedBus() {
    if (_selectedBusId == null) return null;
    final bus = _buses.firstWhere(
      (b) => _parseInt(b["bus_id"]) == _selectedBusId,
      orElse: () => {},
    );
    return _parseInt(bus["operator_id"]);
  }

  Map<String, dynamic> _buildPayload() {
    final operatorFromBus = _operatorIdForSelectedBus();
    final tripDate = _tripDateCtrl.text.trim();
    final status = _normalizeStatusValue(_selectedStatus);
    final departureRaw = _departureCtrl.text.trim();
    final arrivalRaw = _arrivalCtrl.text.trim();
    final departureCombined = _combineDateAndTime(tripDate, departureRaw);
    final arrivalCombined = _combineDateAndTime(tripDate, arrivalRaw);
    final arrivalFinal = _normalizeArrivalAfterDeparture(
      departureCombined,
      arrivalCombined,
    );
    return {
      "routeId": _selectedRouteId,
      "operatorId": operatorFromBus ?? _parseInt(_operatorIdCtrl.text),
      "busId": _selectedBusId,
      "driverId": _selectedDriverId,
      "tripDate": tripDate,
      "departureTime": departureCombined,
      "arrivalTime": arrivalFinal,
      "status": status,
    };
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.addTrip(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Trip added")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateRecord() async {
    final tripId = _tripId;
    if (tripId == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.updateTrip(tripId, _buildPayload());
      final refreshed = await AdminApi.getTrips(tripId: tripId);
      final updated = refreshed.isNotEmpty
          ? Map<String, dynamic>.from(refreshed.first as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Trip updated")));
      Navigator.pop(context, _mergeTripUpdate(updated));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecord() async {
    final tripId = _tripId;
    if (tripId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete trip?"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await AdminApi.deleteTrip(tripId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Trip deleted")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _routeLabel(Map<String, dynamic> route) {
    final name = route["route_name"] ?? route["name"] ?? "";
    final code = route["route_no"] ?? route["route_code"] ?? "";
    return "${name.toString().trim()} (${code.toString().trim()})"
        .replaceAll(RegExp(r"\\s+\\(\\)"), "")
        .trim();
  }

  String _busLabel(Map<String, dynamic> bus) {
    final plate = bus["license_plate_no"] ?? bus["license_plate"] ?? "-";
    final id = bus["bus_id"] ?? "-";
    return "$plate (ID $id)";
  }

  String _driverLabel(Map<String, dynamic> driver) {
    final name = driver["name"] ??
        driver["full_name"] ??
        driver["driver_name"] ??
        "-";
    final id = driver["driver_id"] ?? driver["id"] ?? "-";
    return "$name (ID $id)";
  }

  Map<String, dynamic> _mergeTripUpdate(Map<String, dynamic> updated) {
    final merged = <String, dynamic>{};
    if (widget.trip != null) {
      merged.addAll(widget.trip!);
    }
    merged.addAll(updated);

    if (_selectedRouteId != null) {
      merged["route_id"] = _selectedRouteId;
    }
    if (_selectedBusId != null) {
      merged["bus_id"] = _selectedBusId;
    }
    if (_selectedDriverId != null) {
      merged["driver_id"] = _selectedDriverId;
    }
    if (_selectedStatus.isNotEmpty) {
      merged["status"] = _selectedStatus;
    }
    final tripDate = _tripDateCtrl.text.trim();
    if (tripDate.isNotEmpty) {
      merged["trip_date"] = tripDate;
    }
    final departureCombined =
        _combineDateAndTime(tripDate, _departureCtrl.text.trim());
    if (departureCombined.isNotEmpty) {
      merged["departure_time"] = departureCombined;
    }
    final arrivalCombined =
        _combineDateAndTime(tripDate, _arrivalCtrl.text.trim());
    if (arrivalCombined.isNotEmpty) {
      merged["arrival_time"] =
          _normalizeArrivalAfterDeparture(departureCombined, arrivalCombined);
    }

    final route = _routes.firstWhere(
      (r) => _parseInt(r["route_id"]) == _selectedRouteId,
      orElse: () => {},
    );
    if (route.isNotEmpty) {
      merged["route_name"] = route["route_name"] ?? route["name"];
      merged["route_code"] = route["route_no"] ?? route["route_code"];
    }

    final bus = _buses.firstWhere(
      (b) => _parseInt(b["bus_id"]) == _selectedBusId,
      orElse: () => {},
    );
    if (bus.isNotEmpty) {
      merged["license_plate_no"] =
          bus["license_plate_no"] ?? bus["license_plate"];
    }

    final driver = _drivers.firstWhere(
      (d) => _parseInt(d["driver_id"] ?? d["id"]) == _selectedDriverId,
      orElse: () => {},
    );
    if (driver.isNotEmpty) {
      merged["driver_name"] =
          driver["name"] ?? driver["full_name"] ?? driver["driver_name"];
    }

    return merged;
  }

  void _autoFillOperatorFromBus(int? busId) {
    if (busId == null) return;
    final bus =
        _buses.firstWhere((b) => _parseInt(b["bus_id"]) == busId, orElse: () => {});
    final operatorId = bus["operator_id"];
    if (operatorId != null) {
      _operatorIdCtrl.text = operatorId.toString();
    }
  }

  DateTime _defaultInitialDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  String _formatDateValue(DateTime value) {
    final y = value.year.toString().padLeft(4, "0");
    final m = value.month.toString().padLeft(2, "0");
    final d = value.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = _parseDate(controller.text) ?? _defaultInitialDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    controller.text = _formatDateValue(picked);
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (picked == null) return;
    final h = picked.hour.toString().padLeft(2, "0");
    final m = picked.minute.toString().padLeft(2, "0");
    controller.text = "$h:$m";
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _tripId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? "Edit Trip" : "Add Trip")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isEdit)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Trip ID: ${_tripId ?? "-"}",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedRouteId,
                        items: _routes
                            .map(
                              (r) => DropdownMenuItem<int>(
                                value: _parseInt(r["route_id"]),
                                child: Text(_routeLabel(r)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedRouteId = value),
                        decoration:
                            const InputDecoration(labelText: "Route"),
                        validator: (value) =>
                            value == null ? "Route is required" : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedBusId,
                        items: _buses
                            .map(
                              (b) => DropdownMenuItem<int>(
                                value: _parseInt(b["bus_id"]),
                                child: Text(_busLabel(b)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedBusId = value);
                          _autoFillOperatorFromBus(value);
                        },
                        decoration:
                            const InputDecoration(labelText: "Bus"),
                        validator: (value) =>
                            value == null ? "Bus is required" : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedDriverId,
                        items: _drivers
                            .map(
                              (d) => DropdownMenuItem<int>(
                                value: _parseInt(d["driver_id"] ?? d["id"]),
                                child: Text(_driverLabel(d)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedDriverId = value),
                        decoration:
                            const InputDecoration(labelText: "Driver"),
                        validator: (value) =>
                            value == null ? "Driver is required" : null,
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        label: "Operator ID",
                        controller: _operatorIdCtrl,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if ((value ?? "").trim().isEmpty &&
                              _operatorIdForSelectedBus() == null) {
                            return "Operator ID is required";
                          }
                          return null;
                        },
                        hint: "Auto-filled from selected bus",
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        label: "Trip Date",
                        controller: _tripDateCtrl,
                        hint: "YYYY-MM-DD",
                        readOnly: true,
                        onTap: () => _pickDate(_tripDateCtrl),
                        suffixIcon: Icons.calendar_today,
                        validator: (value) {
                          if ((value ?? "").trim().isEmpty) {
                            return "Trip date is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        label: "Departure Time",
                        controller: _departureCtrl,
                        hint: "HH:MM",
                        readOnly: true,
                        onTap: () => _pickTime(_departureCtrl),
                        suffixIcon: Icons.schedule,
                        validator: (value) {
                          if ((value ?? "").trim().isEmpty) {
                            return "Departure time is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        label: "Arrival Time",
                        controller: _arrivalCtrl,
                        hint: "HH:MM",
                        readOnly: true,
                        onTap: () => _pickTime(_arrivalCtrl),
                        suffixIcon: Icons.schedule,
                        validator: (value) {
                          if ((value ?? "").trim().isEmpty) {
                            return "Arrival time is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        items: const [
                          DropdownMenuItem(
                            value: "scheduled",
                            child: Text("Scheduled"),
                          ),
                          DropdownMenuItem(
                            value: "in_progress",
                            child: Text("In Progress"),
                          ),
                          DropdownMenuItem(
                            value: "completed",
                            child: Text("Completed"),
                          ),
                          DropdownMenuItem(
                            value: "cancelled",
                            child: Text("Cancelled"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedStatus = value);
                        },
                        decoration:
                            const InputDecoration(labelText: "Status"),
                      ),
                      const SizedBox(height: 18),
                      if (!isEdit)
                        ElevatedButton.icon(
                          onPressed: _addRecord,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text("Add Record"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isEdit ? _updateRecord : null,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text("Update"),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isEdit ? _deleteRecord : null,
                              icon: const Icon(Icons.delete_outline),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side:
                                    const BorderSide(color: AppColors.danger),
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              label: const Text("Delete"),
                            ),
                          ),
                        ],
                      ),
                      if (_saving)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null) return "";
  final raw = value.toString();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final y = parsed.year.toString().padLeft(4, "0");
  final m = parsed.month.toString().padLeft(2, "0");
  final d = parsed.day.toString().padLeft(2, "0");
  return "$y-$m-$d";
}

String _formatTime(dynamic value) {
  if (value == null) return "";
  final raw = value.toString().trim();
  if (raw.isEmpty) return "";
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    final h = parsed.hour.toString().padLeft(2, "0");
    final min = parsed.minute.toString().padLeft(2, "0");
    return "$h:$min";
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

String _combineDateAndTime(String dateRaw, String timeRaw) {
  final date = dateRaw.trim();
  final time = timeRaw.trim();
  if (time.isEmpty) return "";
  if (time.contains("-")) return time;
  final normalized = time.length == 5 ? "$time:00" : time;
  if (date.isEmpty) return normalized;
  return "$date $normalized";
}

String _normalizeArrivalAfterDeparture(String departure, String arrival) {
  if (departure.isEmpty || arrival.isEmpty) return arrival;
  final dep = DateTime.tryParse(departure);
  final arr = DateTime.tryParse(arrival);
  if (dep == null || arr == null) return arrival;
  if (!arr.isBefore(dep)) return arrival;
  final nextDay = arr.add(const Duration(days: 1));
  final y = nextDay.year.toString().padLeft(4, "0");
  final m = nextDay.month.toString().padLeft(2, "0");
  final d = nextDay.day.toString().padLeft(2, "0");
  final h = nextDay.hour.toString().padLeft(2, "0");
  final min = nextDay.minute.toString().padLeft(2, "0");
  final sec = nextDay.second.toString().padLeft(2, "0");
  return "$y-$m-$d $h:$min:$sec";
}

String _normalizeStatusValue(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.isEmpty) return "scheduled";
  if (normalized == "in_progress") return "running";
  if (normalized == "in progress") return "running";
  if (normalized == "running") return "running";
  return normalized;
}

String _normalizeStatusForUi(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized == "running") return "in_progress";
  return _normalizeStatusValue(normalized);
}
