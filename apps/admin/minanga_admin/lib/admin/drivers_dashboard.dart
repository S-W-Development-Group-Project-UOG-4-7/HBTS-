import 'package:flutter/material.dart';
import '../services/driver_admin_api.dart';
import 'driver_details_page.dart';
import '../theme/app_theme.dart';

class DriversDashboard extends StatefulWidget {
  const DriversDashboard({super.key});

  @override
  State<DriversDashboard> createState() => _DriversDashboardState();
}

class _DriversDashboardState extends State<DriversDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Pending'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DriverListTab(status: "approved"),
          DriverListTab(status: "pending"),
          DriverListTab(status: "rejected"),
        ],
      ),
    );
  }
}

class DriverListTab extends StatefulWidget {
  const DriverListTab({
    super.key,
    required this.status,
  });

  final String status;

  @override
  State<DriverListTab> createState() => _DriverListTabState();
}

class _DriverListTabState extends State<DriverListTab> {
  List<dynamic> drivers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await DriverAdminApi.list(status: widget.status);
      if (!mounted) return;
      setState(() => drivers = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _text(Map<String, dynamic> driver, List<String> keys,
      {String fallback = "-"}) {
    for (final key in keys) {
      final value = driver[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  int? _id(Map<String, dynamic> driver) {
    final v = driver["driver_id"] ?? driver["id"] ?? driver["driverId"];
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.status == "approved"
        ? AppColors.success
        : widget.status == "pending"
            ? AppColors.warning
            : AppColors.danger;

    Widget content;
    if (loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      content = Center(
        child: Text(
          error ?? "",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    } else if (drivers.isEmpty) {
      content = Center(
        child: Text("No ${widget.status} drivers"),
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: drivers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final driver = drivers[index] as Map<String, dynamic>;
          final id = _id(driver);
          final name = _text(driver, [
            "full_name",
            "name",
            "driver_name",
            "driverName",
            "fullName",
          ]);
          final license = _text(driver, ["license_number", "license"]);
          final operatorName = _text(driver, ["operator_name", "operator"]);
          final phone = _text(driver, ["phone"]);
          final rejectionReason =
              _text(driver, ["rejection_reason", "reason"], fallback: "");

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor,
                child: Icon(
                  widget.status == "approved"
                      ? Icons.check
                      : widget.status == "pending"
                          ? Icons.person
                          : Icons.close,
                  color: Colors.white,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("License: $license"),
                  Text("Bus Operator: $operatorName"),
                  Text("Phone: $phone"),
                  if (widget.status == "rejected" &&
                      rejectionReason.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Reason: $rejectionReason",
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: id == null
                  ? null
                  : () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverDetailsPage(
                            driverId: id,
                            statusHint: widget.status,
                          ),
                        ),
                      );
                      if (changed == true) {
                        _load();
                      }
                    },
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: content is ScrollView
          ? content
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [SizedBox(height: 400, child: Center(child: content))],
            ),
    );
  }
}


