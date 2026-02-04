import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/admin_api.dart';
import '../config.dart';
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
  final _idNumberCtrl = TextEditingController();
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
  String? _existingIdCardUrl;
  String? _idCardName;
  List<int>? _idCardBytes;
  String? _idCardError;

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
      _idNumberCtrl.text = c["id_number"]?.toString() ??
          c["idNumber"]?.toString() ??
          "";
      _phoneCtrl.text = c["phone"]?.toString() ?? "";
      _selectedCompanyId = _toInt(c["operator_id"]);
      _selectedCompanyName = c["company"]?.toString();
      _selectedBusId = _toInt(c["bus_id"]);
      _existingIdCardUrl = c["id_card_image_url"]?.toString();
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
    _idNumberCtrl.dispose();
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
      "id_number": _idNumberCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      if (_passwordCtrl.text.trim().isNotEmpty)
      "password": _passwordCtrl.text,
      "operator_id": _selectedCompanyId,
      "company": _selectedCompanyName,
      "bus_id": _selectedBusId,
      "is_active": _isActive,
    };
  }

  String? _idCardPreviewUrl() {
    final raw = _existingIdCardUrl;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }
    final base = AppConfig.baseUrl.replaceFirst("/api", "");
    return "$base$raw";
  }

  Future<void> _pickIdCard() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _idCardBytes = file.bytes;
      _idCardName = file.name;
      _idCardError = null;
    });
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idCardBytes == null) {
      setState(() => _idCardError = "ID card photo is required");
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      payload["id_card_bytes"] = _idCardBytes;
      payload["id_card_filename"] = _idCardName;
      await AdminApi.addConductor(payload);
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
    if (_idCardBytes == null && (_existingIdCardUrl ?? "").isEmpty) {
      setState(() => _idCardError = "ID card photo is required");
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      if (_idCardBytes != null) {
        payload["id_card_bytes"] = _idCardBytes;
        payload["id_card_filename"] = _idCardName;
      }
      await AdminApi.updateConductor(id, payload);
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
                  controller: _idNumberCtrl,
                  decoration: const InputDecoration(labelText: "ID Number"),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ID Card Photo",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _idCardName ??
                                    (_existingIdCardUrl ?? "No file selected"),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _pickIdCard,
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _idCardBytes != null || _existingIdCardUrl != null
                                    ? "Replace"
                                    : "Upload",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_idCardBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              Uint8List.fromList(_idCardBytes!),
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (_idCardPreviewUrl() != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _idCardPreviewUrl()!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                height: 140,
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: const Text("Failed to load preview"),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.outline),
                            ),
                            alignment: Alignment.center,
                            child: const Text("No preview available"),
                          ),
                        if (_idCardError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _idCardError!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: isEdit ? _updateRecord : _addRecord,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(isEdit ? "Update Conductor" : "Add Conductor"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
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
