import 'package:flutter/material.dart';
import '../services/driver_admin_api.dart';
import '../theme/app_theme.dart';

class DriverReviewForm extends StatefulWidget {
  final Map<String, dynamic> driverData;

  const DriverReviewForm({
    super.key,
    required this.driverData,
  });

  @override
  State<DriverReviewForm> createState() => _DriverReviewFormState();
}

class _DriverReviewFormState extends State<DriverReviewForm> {
  late TextEditingController nameController;
  late TextEditingController licenseController;
  late TextEditingController phoneController;
  late TextEditingController reasonController;

  String selectedOperator = 'SL Bus Company';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: _read(["name", "full_name"]));
    licenseController =
        TextEditingController(text: _read(["license", "license_number"]));
    phoneController = TextEditingController(text: _read(["phone"]));
    reasonController =
        TextEditingController(text: _read(["rejection_reason", "reason"]));
    selectedOperator =
        _read(["operator", "operator_name"], fallback: selectedOperator);
  }

  @override
  void dispose() {
    nameController.dispose();
    licenseController.dispose();
    phoneController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  int? get driverId {
    final v = widget.driverData["driver_id"] ??
        widget.driverData["id"] ??
        widget.driverData["driverId"];
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  String _read(List<String> keys, {String fallback = ""}) {
    for (final key in keys) {
      final value = widget.driverData[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  Future<void> _changeStatus(String status) async {
    final id = driverId;
    if (id == null) {
      _showMessage("Driver ID missing", isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await DriverAdminApi.updateStatus(
        id,
        status,
        reason: status == "rejected" ? reasonController.text.trim() : null,
      );
      if (!mounted) return;
      _showMessage("Driver ${status.toLowerCase()}");
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateDriver() async {
    final id = driverId;
    if (id == null) {
      _showMessage("Driver ID missing", isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await DriverAdminApi.update(
        id,
        fullName: nameController.text.trim(),
        licenseNumber: licenseController.text.trim(),
        phone: phoneController.text.trim(),
        operatorName: selectedOperator,
      );
      if (!mounted) return;
      _showMessage("Driver updated");
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _read(["status"]).toUpperCase();
    final statusColor = status == "APPROVED"
        ? AppColors.success
        : status == "PENDING"
            ? AppColors.warning
            : status == "REJECTED"
                ? AppColors.danger
                : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Driver'),
        actions: [
          if (status.isNotEmpty)
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
                  status,
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
          children: [
            _buildTextField('Driver Name', nameController),
            _buildTextField('License Number', licenseController),
            _buildTextField('Phone Number', phoneController),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedOperator,
              decoration: const InputDecoration(
                labelText: 'Bus Operator',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'SL Bus Company',
                  child: Text('SL Bus Company'),
                ),
                DropdownMenuItem(
                  value: 'Private Owner',
                  child: Text('Private Owner'),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => selectedOperator = value);
                      }
                    },
            ),

            const SizedBox(height: 16),
            _buildTextField(
              'Rejection reason (optional)',
              reasonController,
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    onPressed:
                        _submitting ? null : () => _changeStatus("approved"),
                    child:
                        _submitting ? const Text('Working...') : const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed:
                        _submitting ? null : () => _changeStatus("rejected"),
                    child: _submitting ? const Text('Working...') : const Text('Reject'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _updateDriver,
                    child: _submitting
                        ? const Text('Saving...')
                        : const Text('Update'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: !_submitting,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

