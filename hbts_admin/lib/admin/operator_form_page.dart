import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class OperatorFormPage extends StatefulWidget {
  const OperatorFormPage({super.key, this.operator, this.initialCompany});

  final Map<String, dynamic>? operator;
  final Map<String, dynamic>? initialCompany;

  @override
  State<OperatorFormPage> createState() => _OperatorFormPageState();
}

class _OperatorFormPageState extends State<OperatorFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  List<Map<String, dynamic>> _companies = [];
  bool _loadingCompanies = false;
  bool _saving = false;
  int? _selectedCompanyId;
  String? _selectedCompanyName;

  int? get _operatorUserId {
    final op = widget.operator;
    if (op == null) return null;
    final raw = op["user_id"] ?? op["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  @override
  void initState() {
    super.initState();
    final op = widget.operator;
    if (op != null) {
      _nameCtrl.text = op["name"]?.toString() ?? "";
      _emailCtrl.text = op["email"]?.toString() ?? "";
      _phoneCtrl.text = op["phone"]?.toString() ?? "";
      _selectedCompanyId = _toInt(op["operator_id"]);
      _selectedCompanyName = op["company"]?.toString();
    }
    final initial = widget.initialCompany;
    if (initial != null) {
      _selectedCompanyId = _toInt(initial["operator_id"] ?? initial["company_id"]);
      _selectedCompanyName = initial["name"]?.toString();
    }
    _loadCompanies();
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

  Map<String, dynamic> _buildPayload() {
    return {
      "name": _nameCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      if (_passwordCtrl.text.trim().isNotEmpty)
        "password": _passwordCtrl.text,
      "operator_id": _selectedCompanyId,
      "company": _selectedCompanyName,
    };
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.addOperator(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Operator added")));
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
    final operatorId = _operatorUserId;
    if (operatorId == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.updateOperator(operatorId, _buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Operator updated")));
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
    final isEdit = _operatorUserId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Operator" : "Add Operator"),
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
                  value: _selectedCompanyId,
                  items: _companies
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: _toInt(c["operator_id"] ?? c["company_id"]),
                          child: Text(
                            "${c["name"] ?? "Company"} (ID: ${_toInt(c["operator_id"] ?? c["company_id"]) ?? "-"})",
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
                    });
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
                  label: Text(isEdit ? "Update Operator" : "Add Operator"),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 8),
                Text(
                  "Operators are created in users with role_id = 5.",
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
