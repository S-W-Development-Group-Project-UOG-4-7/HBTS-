import 'package:flutter/material.dart';

class DriverReviewForm extends StatefulWidget {
  final Map<String, String> driverData;

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

  String selectedOperator = 'SL Bus Company';

  @override
  void initState() {
    super.initState();

    // Auto-fill from temp driver data
    nameController =
        TextEditingController(text: widget.driverData['name']);
    licenseController =
        TextEditingController(text: widget.driverData['license']);
    phoneController =
        TextEditingController(text: widget.driverData['phone'] ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    licenseController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Driver'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField('Driver Name', nameController),
            _buildTextField('License Number', licenseController),
            _buildTextField('Phone Number', phoneController),
            const SizedBox(height: 16),

            // Operator dropdown
            DropdownButtonFormField<String>(
              value: selectedOperator,
              decoration: const InputDecoration(
                labelText: 'Operator',
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
              onChanged: (value) {
                setState(() => selectedOperator = value!);
              },
            ),

            const SizedBox(height: 30),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: _approveDriver,
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _rejectDriver,
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _updateDriver,
                    child: const Text('Update'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // TEMP actions (UI only)
  void _approveDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver Approved')),
    );
  }

  void _rejectDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver Rejected')),
    );
  }

  void _updateDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver Updated')),
    );
  }
}
