import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../services/driver_admin_api.dart';
import '../theme/app_theme.dart';

class FullDetailsReportPage extends StatefulWidget {
  const FullDetailsReportPage({super.key});

  @override
  State<FullDetailsReportPage> createState() => _FullDetailsReportPageState();
}

class _FullDetailsReportPageState extends State<FullDetailsReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = "";
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _passengers = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _owners = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final errors = <String>[];

    try {
      final data = await AdminApi.getPassengers("");
      _passengers = data.cast<Map<String, dynamic>>();
    } catch (e) {
      errors.add("Passengers: ${e.toString()}");
      _passengers = [];
    }

    try {
      final data = await DriverAdminApi.list();
      _drivers = data.cast<Map<String, dynamic>>();
    } catch (e) {
      errors.add("Drivers: ${e.toString()}");
      _drivers = [];
    }

    try {
      final data = await AdminApi.getBusOwners();
      _owners = data.cast<Map<String, dynamic>>();
    } catch (e) {
      errors.add("Bus owners: ${e.toString()}");
      _owners = [];
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = errors.isEmpty ? null : errors.join("\n");
    });
  }

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> source,
    List<String> keys,
  ) {
    if (_search.isEmpty) return source;
    final needle = _search.toLowerCase();
    return source.where((item) {
      return keys.any((k) => item[k]?.toString().toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Full Details Report"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Passengers"),
            Tab(text: "Drivers"),
            Tab(text: "Bus Operators"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search name...",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _PassengerList(
                          items:
                              _filter(_passengers, ["name", "email", "phone"]),
                        ),
                        _DriverList(
                          items: _filter(
                            _drivers,
                            ["name", "license_number", "operator_name", "phone"],
                          ),
                        ),
                        _OwnerList(
                          items: _filter(_owners, ["name", "phone", "email"]),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PassengerList extends StatelessWidget {
  const _PassengerList({required this.items});
  final List<Map<String, dynamic>> items;

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  String _formatDate(dynamic v) {
    if (v == null) return "-";
    final raw = v.toString();
    return raw.contains("T") ? raw.split("T")[0] : raw;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text("No passengers found"));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final p = items[index];
        final verified = p["is_verified"] == true ? "Verified" : "Unverified";
        return _Tile(
          title: _safe(p["name"]),
          subtitle:
              "Email: ${_safe(p["email"])}\nPhone: ${_safe(p["phone"])}\nJoined: ${_formatDate(p["created_at"])}",
          badge: verified.toUpperCase(),
          badgeColor: AppColors.primary,
        );
      },
    );
  }
}

class _DriverList extends StatelessWidget {
  const _DriverList({required this.items});
  final List<Map<String, dynamic>> items;

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return AppColors.success;
      case "pending":
        return AppColors.warning;
      case "rejected":
        return AppColors.danger;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text("No drivers found"));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final d = items[index];
        final status = _safe(d["status"]);
        final color = _statusColor(status);
        return _Tile(
          title: _safe(d["name"]),
          subtitle:
              "License: ${_safe(d["license_number"])}\nPhone: ${_safe(d["phone"])}\nBus Operator: ${_safe(d["operator_name"])}",
          badge: status.toUpperCase(),
          badgeColor: color,
        );
      },
    );
  }
}

class _OwnerList extends StatelessWidget {
  const _OwnerList({required this.items});
  final List<Map<String, dynamic>> items;

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text("No bus operators found"));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final op = items[index];
        final status = _safe(op["status"]);
        return _Tile(
          title: _safe(op["name"]),
          subtitle:
              "Fleet size: ${_safe(op["fleet_size"])}\nDrivers: ${_safe(op["drivers"])}\nPhone: ${_safe(op["phone"])}",
          badge: status.toUpperCase(),
          badgeColor: AppColors.accent,
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: badgeColor.withAlpha((0.12 * 255).round()),
          child: Icon(Icons.info, color: badgeColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}


