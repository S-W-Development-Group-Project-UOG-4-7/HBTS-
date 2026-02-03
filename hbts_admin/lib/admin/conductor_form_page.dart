import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class ConductorFormPage extends StatefulWidget {
  const ConductorFormPage({super.key, this.conductor});

  final Map<String, dynamic>? conductor;

  @override
  State<ConductorFormPage> createState() => _ConductorFormPageState();
}

class _ConductorFormPageState extends State<ConductorFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _buses = [];
  bool _loadingCompanies = false;
  bool _loadingBuses = false;
  bool _saving = false;
  int? _selectedCompanyId;
  String? _selectedCompanyName;
  int? _selectedBusId;
  bool _isActive = true;

  int? get _conductorId {
    final c = widget.conductor;
    if (c == null) return null;
    final raw = c["conductor_id"] ?? c["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  @override
  void initState() {
    super.initState();
    final c = widget.conductor;
    if (c != null) {
      _nameCtrl.text = c["name"]?.toString() ?? "";
      _emailCtrl.text = c["email"]?.toString() ?? "";
      _phoneCtrl.text = c["phone"]?.toString() ?? "";
      _selectedCompanyId = _toInt(c["operator_id"]);
      _selectedCompanyName = c["company"]?.toString();
      _selectedBusId = _toInt(c["bus_id"]);
      if (c["is_active"] is bool) {
        _isActive = c["is_active"] == true;
      }
    }
    _loadCompanies();
    _loadBuses();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    try {
      final data = await AdminApi.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = data.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  Future<void> _loadBuses() async {
    if (_selectedCompanyId == null) {
      setState(() {
        _buses = [];
        _selectedBusId = null;
      });
      return;
    }
    setState(() => _loadingBuses = true);
    try {
      final data = await AdminApi.getBuses(operatorId: _selectedCompanyId);
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      int? selected = _selectedBusId;
      if (selected != null &&
          !list.any((b) => _toInt(b["bus_id"]) == selected)) {
        selected = null;
      }
      setState(() {
        _buses = list;
        _selectedBusId = selected;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loadingBuses = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "name": _nameCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      if (_passwordCtrl.text.trim().isNotEmpty)
      "password": _passwordCtrl.text,
      "operator_id": _selectedCompanyId,
      "company": _selectedCompanyName,
      "bus_id": _selectedBusId,
      "is_active": _isActive,
    };
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.addConductor(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Conductor added")));
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
    final id = _conductorId;
    if (id == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.updateConductor(id, _buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Conductor updated")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) {
    return (value ?? "").trim().isEmpty ? "Required" : null;
  }

  String? _requireCompany(int? value) {
    if (value == null) return "Company is required";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _conductorId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Conductor" : "Add Conductor"),
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
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                  keyboardType: TextInputType.emailAddress,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: "Phone"),
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selectedCompanyId,
                  items: _companies
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: _toInt(
                            c["operator_id"] ?? c["company_id"] ?? c["id"],
                          ),
                          child: Text(
                            "${c["name"] ?? "Company"} (ID: ${_toInt(c["operator_id"] ?? c["company_id"] ?? c["id"]) ?? "-"})",
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final company = _companies.firstWhere(
                      (c) =>
                          _toInt(c["operator_id"] ?? c["company_id"]) == value,
                      orElse: () => {},
                    );
                    setState(() {
                      _selectedCompanyId = value;
                      _selectedCompanyName = company["name"]?.toString();
                      _selectedBusId = null;
                    });
                    _loadBuses();
                  },
                  decoration: const InputDecoration(labelText: "Company"),
                  validator: _requireCompany,
                ),
                if (_loadingCompanies)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedBusId,
                  items: _buses
                      .map(
                        (b) => DropdownMenuItem<int?>(
                          value: _toInt(b["bus_id"]),
                          child: Text(
                            "${b["license_plate_no"] ?? "Bus"} (ID: ${_toInt(b["bus_id"]) ?? "-"})",
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedBusId = value);
                  },
                  decoration: const InputDecoration(labelText: "Assign Bus"),
                  validator: (value) {
                    if (value == null) return "Bus is required";
                    return null;
                  },
                ),
                if (_loadingBuses)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text("Active"),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: isEdit ? "Password (optional)" : "Password",
                  ),
                  obscureText: true,
                  validator: isEdit ? null : _required,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: isEdit ? _updateRecord : _addRecord,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEdit ? "Update Conductor" : "Add Conductor"),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 8),
                Text(
                  "Conductors are created in users with role_id = 6.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
