import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorAssignmentsPage extends StatefulWidget {
  const OperatorAssignmentsPage({super.key});

  @override
  State<OperatorAssignmentsPage> createState() => _OperatorAssignmentsPageState();
}

class _OperatorAssignmentsPageState extends State<OperatorAssignmentsPage> {
  late Future<List<Map<String, dynamic>>> _driversFuture;
  late Future<List<Map<String, dynamic>>> _busesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _driversFuture = OperatorApi.fetchDrivers();
    _busesFuture = OperatorApi.fetchBuses();
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

  Widget _avatar(String? url, IconData icon) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.blue.shade50,
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.blue.shade50,
      child: Icon(icon, color: Colors.blue.shade700),
    );
  }

  Widget _docThumb(String label, String url) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
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
    final busId = _safeStr(driver["bus_id"] ?? driver["busId"]);
    final status = _safeStr(driver["status"]);

    if (phone != "-") details.add("Phone: $phone");
    if (email != "-") details.add("Email: $email");
    if (licenseNo != "-") details.add("License: $licenseNo");
    if (busId != "-") details.add("Bus: $busId");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Drivers and Buses"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
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
            const SizedBox(height: 20),
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
        ),
      ),
    );
  }
}
