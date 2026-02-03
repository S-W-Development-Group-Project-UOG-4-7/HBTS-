import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class CustomerDetailsPage extends StatefulWidget {
  final int userId;

  const CustomerDetailsPage({super.key, required this.userId});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  Map<String, dynamic>? customer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    try {
      final data = await AdminApi.fetchPassengerDetails(widget.userId);
      if (!mounted) return;
      setState(() {
        customer = data;
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
            width: 110,
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

  // ================= DELETE =================
  Future<void> _deletePassenger() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Passenger"),
        content: const Text(
          "Are you sure you want to delete this passenger?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AdminApi.deletePassenger(widget.userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passenger deleted successfully")),
      );

      Navigator.pop(context);
    }
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

    return Scaffold(
      appBar: AppBar(title: const Text("Customer Details")),
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
                      _safe(customer!["name"]),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(_safe(customer!["email"])),
                    const SizedBox(height: 12),
                    _detailRow("User ID", _safe(customer!["user_id"])),
                    _detailRow("Phone", _safe(customer!["phone"])),
                    _detailRow("Role", _safe(customer!["role_name"])),
                    _detailRow(
                      "Verified",
                      _safe(customer!["is_verified"]),
                    ),
                    _detailRow(
                      "Joined",
                      _formatDate(customer!["created_at"]),
                    ),
                    _detailRow(
                      "Updated",
                      _formatDate(customer!["updated_at"]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Actions",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text("Delete"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: _deletePassenger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
