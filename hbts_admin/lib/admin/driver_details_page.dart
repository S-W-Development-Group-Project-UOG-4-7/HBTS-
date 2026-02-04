import 'package:flutter/material.dart';
import '../services/driver_admin_api.dart';
import 'driver_review_form.dart';
import '../theme/app_theme.dart';

class DriverDetailsPage extends StatefulWidget {
  final int driverId;
  final String? statusHint;

  const DriverDetailsPage({
    super.key,
    required this.driverId,
    this.statusHint,
  });

  @override
  State<DriverDetailsPage> createState() => _DriverDetailsPageState();
}

class _DriverDetailsPageState extends State<DriverDetailsPage> {
  Map<String, dynamic>? driver;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DriverAdminApi.fetch(widget.driverId);
      if (!mounted) return;
      setState(() {
        driver = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  String _formatDate(dynamic v) {
    if (v == null) return "-";
    final raw = v.toString();
    return raw.contains("T") ? raw.split("T")[0] : raw;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _statusValue() {
    final raw = _safe(driver?["status"]);
    if (raw == "-" && widget.statusHint != null) return widget.statusHint!;
    return raw;
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == "approved") return AppColors.success;
    if (s == "pending") return AppColors.warning;
    if (s == "rejected") return AppColors.danger;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
      );
    }

    final status = _statusValue();
    final statusColor = _statusColor(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Details"),
        actions: [
          if (status.isNotEmpty && status != "-")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safe(driver?["name"]),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    _detailRow("Driver ID", _safe(driver?["driver_id"])),
                    _detailRow("License", _safe(driver?["license_number"])),
                    _detailRow("Phone", _safe(driver?["phone"])),
                    _detailRow("Bus Operator", _safe(driver?["operator_name"])),
                    _detailRow("Bus Operator ID", _safe(driver?["operator_id"])),
                    _detailRow("Source", _safe(driver?["source"])),
                    _detailRow(
                      "Joined",
                      _formatDate(driver?["created_at"]),
                    ),
                    _detailRow(
                      "Updated",
                      _formatDate(driver?["updated_at"]),
                    ),
                    if (_safe(driver?["rejection_reason"]) != "-")
                      _detailRow(
                        "Rejection",
                        _safe(driver?["rejection_reason"]),
                      ),
                  ],
                ),
              ),
            ),
            if (status.toLowerCase() == "pending")
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 36,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.assignment_turned_in, size: 18),
                          label: const Text("Review"),
                          onPressed: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DriverReviewForm(driverData: driver ?? {}),
                              ),
                            );
                            if (changed == true) {
                              await _load();
                              if (!context.mounted) return;
                              Navigator.pop(context, true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

