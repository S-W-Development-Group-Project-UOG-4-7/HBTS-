import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/operator_api.dart';

class OperatorStaffRegisterPage extends StatefulWidget {
  final String initialRole;
  final bool allowRoleSelection;

  const OperatorStaffRegisterPage({
    super.key,
    required this.initialRole,
    this.allowRoleSelection = true,
  });

  @override
  State<OperatorStaffRegisterPage> createState() =>
      _OperatorStaffRegisterPageState();
}

class _OperatorStaffRegisterPageState extends State<OperatorStaffRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _licenseController = TextEditingController();

  final _picker = ImagePicker();
  XFile? _profileImage;
  XFile? _idCardImage;

  List<Map<String, dynamic>> _buses = const [];
  bool _loadingBuses = false;
  String? _busError;
  int? _selectedBusId;

  bool _isSubmitting = false;
  late String _role;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    if (_role == "conductor") {
      _loadBuses();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  int? _busIdFrom(Map<String, dynamic> bus) {
    final raw = bus["bus_id"] ?? bus["id"] ?? bus["busId"];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  String _busLabel(Map<String, dynamic> bus) {
    return (bus["license_plate_no"] ??
            bus["plate_no"] ??
            bus["license_no"] ??
            bus["licensePlateNo"] ??
            "Bus")
        .toString();
  }

  Future<void> _loadBuses() async {
    if (_loadingBuses) return;
    setState(() {
      _loadingBuses = true;
      _busError = null;
    });

    try {
      final buses = await OperatorApi.fetchBuses();
      final selected = _selectedBusId ??
          (buses.isNotEmpty ? _busIdFrom(buses.first) : null);
      if (!mounted) return;
      setState(() {
        _buses = buses;
        _selectedBusId = selected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingBuses = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() => _profileImage = image);
  }

  Future<void> _pickIdCardImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() => _idCardImage = image);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profileImage == null || _idCardImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add profile and ID card photos.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final profileBytes = await _profileImage!.readAsBytes();
      final idCardBytes = await _idCardImage!.readAsBytes();

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final idNumber = _idNumberController.text.trim();
      final licenseNo = _licenseController.text.trim();
      final busId = _selectedBusId;

      if (_role == "conductor" && busId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a bus for the conductor.")),
        );
        return;
      }

      if (_role == "driver") {
        await OperatorApi.createDriver(
          name: name,
          phone: phone,
          email: email,
          idNumber: idNumber,
          licenseNo: licenseNo.isEmpty ? null : licenseNo,
          profileImageBytes: profileBytes,
          profileImageName: _profileImage!.name,
          idCardImageBytes: idCardBytes,
          idCardImageName: _idCardImage!.name,
        );
      } else {
        await OperatorApi.createConductor(
          name: name,
          phone: phone,
          email: email,
          idNumber: idNumber,
          busId: busId!,
          profileImageBytes: profileBytes,
          profileImageName: _profileImage!.name,
          idCardImageBytes: idCardBytes,
          idCardImageName: _idCardImage!.name,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to register: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _imageCard({
    required String label,
    required XFile? image,
    required VoidCallback onPick,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPick,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (image == null) ...[
                Icon(Icons.photo_camera, color: Colors.blue.shade600, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ] else
                FutureBuilder<Uint8List>(
                  future: image.readAsBytes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 72,
                        width: 72,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        snapshot.data!,
                        height: 96,
                        width: 96,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _role == "driver" ? "Register Driver" : "Register Conductor";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              if (widget.allowRoleSelection) ...[
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: InputDecoration(
                    labelText: "Role",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: "driver", child: Text("Driver")),
                    DropdownMenuItem(value: "conductor", child: Text("Conductor")),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _role = value);
                          if (value == "conductor") {
                            _loadBuses();
                          }
                        },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Phone number is required"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Email is required";
                  }
                  if (!value.contains("@")) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idNumberController,
                decoration: InputDecoration(
                  labelText: "ID Number",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "ID number is required" : null,
              ),
              if (_role == "conductor") ...[
                const SizedBox(height: 16),
                if (_loadingBuses) const LinearProgressIndicator(),
                if (_busError != null && _busError!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _busError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                if (!_loadingBuses) ...[
                  if (_buses.isEmpty)
                    const Text(
                      "No buses found. Add a bus before registering a conductor.",
                    )
                  else
                    DropdownButtonFormField<int>(
                      value: _selectedBusId,
                      decoration: InputDecoration(
                        labelText: "Assign Bus",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _buses
                          .map((bus) {
                            final id = _busIdFrom(bus);
                            if (id == null) return null;
                            return DropdownMenuItem(
                              value: id,
                              child: Text("Bus $id - ${_busLabel(bus)}"),
                            );
                          })
                          .whereType<DropdownMenuItem<int>>()
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _selectedBusId = value),
                      validator: (value) =>
                          value == null ? "Select a bus for the conductor" : null,
                    ),
                ],
              ],
              if (_role == "driver") ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: "License Number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? "License number is required" : null,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  _imageCard(
                    label: "Profile Photo",
                    image: _profileImage,
                    onPick: _isSubmitting ? () {} : _pickProfileImage,
                  ),
                  const SizedBox(width: 12),
                  _imageCard(
                    label: "ID Card Photo",
                    image: _idCardImage,
                    onPick: _isSubmitting ? () {} : _pickIdCardImage,
                  ),
                ],
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
                          "Register",
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
