import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class RouteFormPage extends StatefulWidget {
  const RouteFormPage({super.key, this.route});

  final Map<String, dynamic>? route;

  @override
  State<RouteFormPage> createState() => _RouteFormPageState();
}

class _RouteFormPageState extends State<RouteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  bool _saving = false;

  int? get _routeId {
    final route = widget.route;
    if (route == null) return null;
    final raw = route["route_id"] ??
        route["id"] ??
        route["routeId"] ??
        route["routeid"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route != null) {
      _nameCtrl.text = _pick(route, ["route_name", "name"]) ?? "";
      _codeCtrl.text =
          _pick(route, ["route_no", "route_number", "route_code", "code"]) ??
              "";
      _originCtrl.text =
          _pick(route, ["origin", "start_point", "start", "from_location", "from"]) ?? "";
      _destinationCtrl.text =
          _pick(route, ["destination", "end_point", "end", "to_location", "to"]) ?? "";
      _distanceCtrl.text =
          _pick(route, ["distance_km", "distance"]) ?? "";
      _fareCtrl.text = _pick(route, ["fare", "price"]) ?? "";
      _statusCtrl.text = _pick(route, ["status", "route_status"]) ?? "";
      _descriptionCtrl.text = _pick(route, ["description", "notes"]) ?? "";
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _distanceCtrl.dispose();
    _fareCtrl.dispose();
    _statusCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String? _pick(Map<String, dynamic> route, List<String> keys) {
    for (final key in keys) {
      final value = route[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  num? _parseNum(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return num.tryParse(trimmed);
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "name": _nameCtrl.text.trim(),
      "code": _codeCtrl.text.trim(),
      "origin": _originCtrl.text.trim(),
      "destination": _destinationCtrl.text.trim(),
      "from_location": _originCtrl.text.trim(),
      "to_location": _destinationCtrl.text.trim(),
      "distance": _parseNum(_distanceCtrl.text),
      "fare": _parseNum(_fareCtrl.text),
      "status": _statusCtrl.text.trim(),
      "description": _descriptionCtrl.text.trim(),
    };
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.addRoute(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Route added")));
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
    final routeId = _routeId;
    if (routeId == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.updateRoute(routeId, _buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Route updated")));
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
    final routeId = _routeId;
    if (routeId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete route?"),
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
      await AdminApi.deleteRoute(routeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Route deleted")));
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _routeId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Route" : "Add Route"),
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
                      "Route ID: ${_routeId ?? "-"}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                _field(
                  label: "Route Name",
                  controller: _nameCtrl,
                  validator: (value) =>
                      (value ?? "").trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Route Code / Number",
                  controller: _codeCtrl,
                  validator: (value) =>
                      (value ?? "").trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Origin",
                  controller: _originCtrl,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Destination",
                  controller: _destinationCtrl,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Distance",
                  controller: _distanceCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Fare",
                  controller: _fareCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Status",
                  controller: _statusCtrl,
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Description",
                  controller: _descriptionCtrl,
                  maxLines: 3,
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
