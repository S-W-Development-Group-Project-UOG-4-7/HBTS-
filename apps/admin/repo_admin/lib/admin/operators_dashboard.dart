import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'operator_form_page.dart';

class OperatorsDashboard extends StatefulWidget {
  const OperatorsDashboard({super.key});

  @override
  State<OperatorsDashboard> createState() => _OperatorsDashboardState();
}

class _OperatorsDashboardState extends State<OperatorsDashboard> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _operators = [];
  List<Map<String, dynamic>> _companies = [];
  bool _loading = false;
  String? _error;
  int? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadOperators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOperators({String search = ""}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getOperators(
        search: search,
        companyId: _selectedCompanyId,
      );
      if (!mounted) return;
      setState(() {
        _operators = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  Future<void> _loadCompanies() async {
    try {
      final data = await AdminApi.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = data.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // ignore company load errors for now
    }
  }

  int? _operatorId(Map<String, dynamic> op) {
    final raw = op["user_id"] ?? op["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  Future<void> _openAddRecord() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OperatorFormPage()),
    );
    if (changed == true) {
      await _loadOperators(search: _searchController.text.trim());
    }
  }

  Future<void> _openEdit(Map<String, dynamic> operator) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OperatorFormPage(operator: operator),
      ),
    );
    if (changed == true) {
      await _loadOperators(search: _searchController.text.trim());
    }
  }

  Future<void> _deleteOperator(Map<String, dynamic> operator) async {
    final id = _operatorId(operator);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete operator?"),
        content: const Text("Are you sure you want to delete this operator?"),
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

    try {
      await AdminApi.deleteOperator(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Operator deleted")),
      );
      await _loadOperators(search: _searchController.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Operators"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _openAddRecord,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("Add Operator"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final searchField = Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _loadOperators(search: value.trim());
                      },
                      decoration: const InputDecoration(
                        hintText: "Search operator by name or email",
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                );

                final filterField = _companies.isNotEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCompanyId,
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Companies"),
                              ),
                              ..._companies.map(
                                (c) => DropdownMenuItem<int?>(
                                  value: _toInt(
                                    c["operator_id"] ??
                                        c["company_id"] ??
                                        c["id"],
                                  ),
                                  child: Text(
                                    "${c["name"] ?? "Company"} (ID: ${_toInt(c["operator_id"] ?? c["company_id"] ?? c["id"]) ?? "-"})",
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCompanyId = value);
                              _loadOperators(
                                search: _searchController.text.trim(),
                              );
                            },
                            decoration: const InputDecoration(
                              labelText: "Filter by Company",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink();

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: searchField),
                      if (_companies.isNotEmpty) const SizedBox(width: 12),
                      if (_companies.isNotEmpty)
                        Expanded(child: filterField),
                    ],
                  );
                }

                return Column(
                  children: [
                    searchField,
                    if (_companies.isNotEmpty) const SizedBox(height: 12),
                    if (_companies.isNotEmpty) filterField,
                  ],
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: _operators.isEmpty && !_loading
                ? const Center(child: Text("No operators found"))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _operators.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final op = _operators[index];
                      final operatorId = _operatorId(op);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.accent.withAlpha((0.12 * 255).round()),
                            child: const Icon(
                              Icons.person,
                              color: AppColors.accent,
                            ),
                          ),
                          title: Text(_safe(op["name"])),
                          subtitle: Text(
                            "Email: ${_safe(op["email"])}\nPhone: ${_safe(op["phone"])}\nCompany: ${_safe(op["company"])}\nCompany ID: ${_safe(op["operator_id"])}\nUser ID: ${operatorId ?? "-"}",
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: "Edit",
                                onPressed: () => _openEdit(op),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: "Delete",
                                onPressed: () => _deleteOperator(op),
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.danger,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
