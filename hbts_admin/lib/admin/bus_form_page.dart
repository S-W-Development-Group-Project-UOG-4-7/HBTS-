import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class BusFormPage extends StatefulWidget {
  const BusFormPage({super.key, this.bus});

  final Map<String, dynamic>? bus;

  @override
  State<BusFormPage> createState() => _BusFormPageState();
}

class _BusFormPageState extends State<BusFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _operatorIdCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serviceTypeCtrl = TextEditingController();

  List<Map<String, dynamic>> _conductors = [];
  bool _loadingConductors = false;
  int? _selectedConductorId;

  bool _saving = false;

  int? get _busId {
    final bus = widget.bus;
    if (bus == null) return null;
    final raw = bus["bus_id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  @override
  void initState() {
    super.initState();
    final bus = widget.bus;
    if (bus != null) {
      _operatorIdCtrl.text = bus["operator_id"]?.toString() ?? "";
      _plateCtrl.text = bus["license_plate_no"]?.toString() ?? "";
      _routeCtrl.text = bus["route_no"]?.toString() ?? "";
      _capacityCtrl.text = bus["capacity"]?.toString() ?? "";
      _modelCtrl.text = bus["model"]?.toString() ?? "";
      _serviceTypeCtrl.text = bus["service_type"]?.toString() ?? "";
    }
    _loadConductors();
  }

  @override
  void dispose() {
    _operatorIdCtrl.dispose();
    _plateCtrl.dispose();
    _routeCtrl.dispose();
    _capacityCtrl.dispose();
    _modelCtrl.dispose();
    _serviceTypeCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  Future<void> _loadConductors() async {
    setState(() => _loadingConductors = true);
    try {
      final data = await AdminApi.getConductors();
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      int? selected;
      final busId = _busId;
      if (busId != null) {
        final match = list.firstWhere(
          (c) => _toInt(c["bus_id"]) == busId,
          orElse: () => {},
        );
        selected = _toInt(match["conductor_id"] ?? match["id"]);
      }
      setState(() {
        _conductors = list;
        _selectedConductorId = selected;
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingConductors = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "operatorId": _parseInt(_operatorIdCtrl.text),
      "conductorId": _selectedConductorId,
      "licensePlateNo": _plateCtrl.text.trim(),
      "routeNo": _routeCtrl.text.trim(),
      "capacity": _parseInt(_capacityCtrl.text),
      "model": _modelCtrl.text.trim(),
      "serviceType": _serviceTypeCtrl.text.trim(),
    };
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.addBus(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bus added")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateRecord() async {
    final busId = _busId;
    if (busId == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.updateBus(busId, _buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bus updated")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecord() async {
    final busId = _busId;
    if (busId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete bus?"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await AdminApi.deleteBus(busId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bus deleted")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _busId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Bus" : "Add Bus Record"),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isEdit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      "Bus ID: ${_busId ?? "-"}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                _field(
                  label: "Operator ID",
                  controller: _operatorIdCtrl,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if ((value ?? "").trim().isEmpty) {
                      return "Operator ID is required";
                    }
                    if (_parseInt(value!) == null) {
                      return "Operator ID must be a number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  label: "License Plate Number",
                  controller: _plateCtrl,
                  validator: (value) =>
                      (value ?? "").trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Route",
                  controller: _routeCtrl,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Capacity",
                  controller: _capacityCtrl,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if ((value ?? "").trim().isEmpty) return null;
                    if (_parseInt(value!) == null) {
                      return "Capacity must be a number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Model",
                  controller: _modelCtrl,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Service Type",
                  controller: _serviceTypeCtrl,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedConductorId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("No Conductor"),
                    ),
                    ..._conductors.map(
                      (c) => DropdownMenuItem<int?>(
                        value: _toInt(c["conductor_id"] ?? c["id"]),
                        child: Text(
                          "${c["name"] ?? "Conductor"} (ID: ${_toInt(c["conductor_id"] ?? c["id"]) ?? "-"})",
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedConductorId = value);
                  },
                  decoration: const InputDecoration(
                    labelText: "Assign Conductor",
                  ),
                  validator: (value) {
                    if (value == null) return "Conductor is required";
                    return null;
                  },
                ),
                if (_loadingConductors)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 18),
                if (!isEdit)
                  ElevatedButton.icon(
                    onPressed: _addRecord,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Add Record"),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isEdit ? _updateRecord : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text("Update"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isEdit ? _deleteRecord : null,
                        icon: const Icon(Icons.delete_outline),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        label: const Text("Delete"),
                      ),
                    ),
                  ],
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
