import 'package:flutter/material.dart';
import 'services/operator_api.dart';
import 'operator_staff_register_page.dart';
import 'operator_bus_register_page.dart';
import '../../config.dart';

enum OperatorAssignmentsView { all, drivers, conductors, buses }

class OperatorAssignmentsPage extends StatefulWidget {
  final OperatorAssignmentsView view;

  const OperatorAssignmentsPage({
    super.key,
    this.view = OperatorAssignmentsView.all,
  });

  @override
  State<OperatorAssignmentsPage> createState() => _OperatorAssignmentsPageState();
}

class _OperatorAssignmentsPageState extends State<OperatorAssignmentsPage> {
  late Future<List<Map<String, dynamic>>> _driversFuture;
  late Future<List<Map<String, dynamic>>> _conductorsFuture;
  late Future<List<Map<String, dynamic>>> _busesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final showDrivers = widget.view == OperatorAssignmentsView.all ||
        widget.view == OperatorAssignmentsView.drivers;
    final showConductors = widget.view == OperatorAssignmentsView.all ||
        widget.view == OperatorAssignmentsView.conductors;
    final showBuses = widget.view == OperatorAssignmentsView.all ||
        widget.view == OperatorAssignmentsView.buses;

    _driversFuture =
        showDrivers ? OperatorApi.fetchDrivers() : Future.value(const []);
    _conductorsFuture =
        showConductors ? OperatorApi.fetchConductors() : Future.value(const []);
    _busesFuture = showBuses ? OperatorApi.fetchBuses() : Future.value(const []);
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  int? _idFrom(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _busLabel(Map<String, dynamic> bus) {
    return _safeStr(
      bus["license_plate_no"] ??
          bus["plate_no"] ??
          bus["license_no"] ??
          bus["licensePlateNo"],
    );
  }

  String? _firstNonEmpty(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _resolveUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    if (trimmed.startsWith("/")) {
      return "${AppConfig.baseUrl}$trimmed";
    }
    return "${AppConfig.baseUrl}/$trimmed";
  }

  Widget _avatar(String? url, IconData icon) {
    final resolved = _resolveUrl(url);
    if (resolved != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(resolved),
        backgroundColor: Colors.blue.shade50,
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.blue.shade50,
      child: Icon(icon, color: Colors.blue.shade700),
    );
  }

  Widget _docThumb(String label, String url) {
    final resolved = _resolveUrl(url);
    if (resolved == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            color: Colors.blue.shade50,
            alignment: Alignment.center,
            child: Icon(Icons.image_not_supported, color: Colors.blue.shade200),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            resolved,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) {
              return Container(
                width: 72,
                height: 72,
                color: Colors.blue.shade50,
                alignment: Alignment.center,
                child: Icon(Icons.image_not_supported, color: Colors.blue.shade200),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  List<String> _driverDetails(Map<String, dynamic> driver) {
    final details = <String>[];
    final phone = _safeStr(driver["phone"]);
    final email = _safeStr(driver["email"] ?? driver["driver_email"]);
    final licenseNo = _safeStr(driver["license_no"] ?? driver["licenseNo"]);
    final idNumber = _safeStr(driver["id_number"] ?? driver["idNumber"]);
    final busId = _safeStr(driver["bus_id"] ?? driver["busId"]);
    final status = _safeStr(driver["status"]);

    if (phone != "-") details.add("Phone: $phone");
    if (email != "-") details.add("Email: $email");
    if (licenseNo != "-") details.add("License: $licenseNo");
    if (idNumber != "-") details.add("ID No: $idNumber");
    if (busId != "-") details.add("Bus: $busId");
    if (status != "-") details.add("Status: $status");

    return details;
  }

  List<String> _conductorDetails(Map<String, dynamic> conductor) {
    final details = <String>[];
    final phone = _safeStr(conductor["phone"]);
    final email = _safeStr(conductor["email"]);
    final idNumber = _safeStr(conductor["id_number"] ?? conductor["idNumber"]);
    final status = _safeStr(conductor["status"]);

    if (phone != "-") details.add("Phone: $phone");
    if (email != "-") details.add("Email: $email");
    if (idNumber != "-") details.add("ID No: $idNumber");
    if (status != "-") details.add("Status: $status");

    return details;
  }
  List<String> _busDetails(Map<String, dynamic> bus) {
    final details = <String>[];
    final capacity = _safeStr(bus["capacity"] ?? bus["seats_total"]);
    final model = _safeStr(bus["model"]);
    final service = _safeStr(bus["service_type"] ?? bus["serviceType"]);
    final status = _safeStr(bus["status"]);

    if (capacity != "-") details.add("Capacity: $capacity");
    if (model != "-") details.add("Model: $model");
    if (service != "-") details.add("Service: $service");
    if (status != "-") details.add("Status: $status");

    return details;
  }

  String _pageTitle() {
    switch (widget.view) {
      case OperatorAssignmentsView.drivers:
        return "Drivers";
      case OperatorAssignmentsView.conductors:
        return "Conductors";
      case OperatorAssignmentsView.buses:
        return "Buses";
      case OperatorAssignmentsView.all:
        return "Drivers, Conductors, and Buses";
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDrivers = widget.view == OperatorAssignmentsView.all ||
        widget.view == OperatorAssignmentsView.drivers;
    final showConductors = widget.view == OperatorAssignmentsView.all ||
        widget.view == OperatorAssignmentsView.conductors;
    final showBuses = widget.view == OperatorAssignmentsView.all ||
        widget.view == OperatorAssignmentsView.buses;

    final showBusFab =
        showBuses && !(showDrivers || showConductors) && widget.view == OperatorAssignmentsView.buses;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle()),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: showBusFab
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const OperatorBusRegisterPage()),
                );

                if (created == true) {
                  _reload();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text("Register Bus"),
              backgroundColor: Colors.blue.shade700,
            )
          : (showDrivers || showConductors)
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final initialRole = widget.view == OperatorAssignmentsView.conductors
                        ? "conductor"
                        : "driver";
                    final allowRoleSelection = true;

                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OperatorStaffRegisterPage(
                          initialRole: initialRole,
                          allowRoleSelection: allowRoleSelection,
                        ),
                      ),
                    );

                    if (created == true) {
                      _reload();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Register Staff"),
                  backgroundColor: Colors.blue.shade700,
                )
              : null,
      body: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (showDrivers) ...[
              const Text(
                "Drivers",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _driversFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  final drivers = snapshot.data ?? [];
                  if (drivers.isEmpty) {
                    return const Text("No drivers available.");
                  }
                  return Column(
                    children: drivers.map((driver) {
                      final name = _safeStr(driver["name"]);
                      final driverId = _idFrom(driver, ["driver_id", "id", "driverId"]);
                      final photoUrl = _firstNonEmpty(driver, [
                        "profile_image_url",
                        "profile_photo_url",
                        "profile_photo",
                        "photo_url",
                        "image_url",
                        "avatar_url",
                        "profileImage",
                      ]);
                      final licenseImage = _firstNonEmpty(driver, [
                        "license_image_url",
                        "license_photo_url",
                        "license_image",
                      ]);
                      final idCardImage = _firstNonEmpty(driver, [
                        "id_card_image_url",
                        "id_card_photo_url",
                        "id_card_image",
                      ]);
                      final details = _driverDetails(driver);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _avatar(photoUrl, Icons.person),
                                title: Text(
                                  driverId == null ? name : "$name (ID: $driverId)",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: details.isEmpty
                                    ? const Text("No additional driver details.")
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: details
                                            .map((line) => Text(
                                                  line,
                                                  style: TextStyle(color: Colors.grey.shade700),
                                                ))
                                            .toList(),
                                      ),
                              ),
                              if (licenseImage != null || idCardImage != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    if (licenseImage != null) _docThumb("License", licenseImage),
                                    if (idCardImage != null) _docThumb("ID Card", idCardImage),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              if (showConductors || showBuses) const SizedBox(height: 20),
            ],
            if (showConductors) ...[
              const Text(
                "Conductors",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _conductorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  final conductors = snapshot.data ?? [];
                  if (conductors.isEmpty) {
                    return const Text("No conductors available.");
                  }
                  return Column(
                    children: conductors.map((conductor) {
                      final name = _safeStr(conductor["name"]);
                      final conductorId =
                          _idFrom(conductor, ["conductor_id", "id", "conductorId"]);
                      final photoUrl = _firstNonEmpty(conductor, [
                        "profile_image_url",
                        "profile_photo_url",
                        "profile_photo",
                        "photo_url",
                        "image_url",
                        "avatar_url",
                        "profileImage",
                      ]);
                      final idCardImage = _firstNonEmpty(conductor, [
                        "id_card_image_url",
                        "id_card_photo_url",
                        "id_card_image",
                      ]);
                      final details = _conductorDetails(conductor);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _avatar(photoUrl, Icons.badge),
                                title: Text(
                                  conductorId == null
                                      ? name
                                      : "$name (ID: $conductorId)",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: details.isEmpty
                                    ? const Text("No additional conductor details.")
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: details
                                            .map((line) => Text(
                                                  line,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                              ),
                              if (idCardImage != null) ...[
                                const SizedBox(height: 8),
                                _docThumb("ID Card", idCardImage),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              if (showBuses) const SizedBox(height: 20),
            ],
            if (showBuses) ...[
              const Text(
                "Buses",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _busesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  final buses = snapshot.data ?? [];
                  if (buses.isEmpty) {
                    return const Text("No buses available.");
                  }
                  return Column(
                    children: buses.map((bus) {
                      final busId = _idFrom(bus, ["bus_id", "id", "busId"]);
                      final plate = _busLabel(bus);
                      final photoUrl = _firstNonEmpty(bus, [
                        "photo_url",
                        "image_url",
                        "bus_photo_url",
                        "bus_image_url",
                      ]);
                      final details = _busDetails(bus);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: const Color.fromARGB(255, 41, 124, 192)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _avatar(photoUrl, Icons.directions_bus),
                                title: Text(
                                  busId == null ? "Bus - $plate" : "Bus $busId - $plate",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: details.isEmpty
                                    ? const Text("No additional bus details.")
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: details
                                            .map((line) => Text(
                                                  line,
                                                  style: TextStyle(color: Colors.grey.shade700),
                                                ))
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
