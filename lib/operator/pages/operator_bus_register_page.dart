import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorBusRegisterPage extends StatefulWidget {
  const OperatorBusRegisterPage({super.key});

  @override
  State<OperatorBusRegisterPage> createState() => _OperatorBusRegisterPageState();
}

class _OperatorBusRegisterPageState extends State<OperatorBusRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _capacityController = TextEditingController();
  final _modelController = TextEditingController();

  bool _isSubmitting = false;
  String _serviceType = "normal";

  @override
  void dispose() {
    _plateController.dispose();
    _capacityController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cap = int.tryParse(_capacityController.text.trim());
    if (cap == null || cap <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Capacity must be a positive number.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await OperatorApi.createBus(
        plateNo: _plateController.text.trim(),
        capacity: cap,
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        serviceType: _serviceType,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to register bus: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Bus"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _plateController,
                decoration: InputDecoration(
                  labelText: "License Plate Number",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Plate number is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Capacity",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Capacity is required" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _serviceType,
                decoration: InputDecoration(
                  labelText: "Service Type",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: "normal", child: Text("Normal")),
                  DropdownMenuItem(value: "semi_luxury", child: Text("Semi Luxury")),
                  DropdownMenuItem(value: "luxury", child: Text("Luxury")),
                  DropdownMenuItem(value: "super_luxury", child: Text("Super Luxury")),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _serviceType = value);
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: "Model (optional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Register Bus",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
