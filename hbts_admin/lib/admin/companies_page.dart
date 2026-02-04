import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'company_form_page.dart';
import 'operator_form_page.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _companies = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies({String search = ""}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getCompanies(search: search);
      if (!mounted) return;
      setState(() {
        _companies = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  int? _companyId(Map<String, dynamic> c) {
    final raw = c["operator_id"] ?? c["company_id"] ?? c["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  Future<void> _openAddRecord() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompanyFormPage()),
    );
    if (changed == true) {
      await _loadCompanies(search: _searchController.text.trim());
    }
  }

  Future<void> _openEdit(Map<String, dynamic> company) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyFormPage(company: company)),
    );
    if (changed == true) {
      await _loadCompanies(search: _searchController.text.trim());
    }
  }

  Future<void> _deleteCompany(Map<String, dynamic> company) async {
    final id = _companyId(company);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete company?"),
        content: const Text("Are you sure you want to delete this company?"),
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
      await AdminApi.deleteCompany(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Company deleted")),
      );
      await _loadCompanies(search: _searchController.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openAddOperator(Map<String, dynamic> company) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OperatorFormPage(initialCompany: company),
      ),
    );
    if (changed == true) {
      await _loadCompanies(search: _searchController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Companies"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _openAddRecord,
              icon: const Icon(Icons.add_business),
              label: const Text("Add Company"),
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
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _loadCompanies(search: value.trim());
                  },
                  decoration: const InputDecoration(
                    hintText: "Search company by name or email",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                ),
              ),
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
            child: _companies.isEmpty && !_loading
                ? const Center(child: Text("No companies found"))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _companies.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = _companies[index];
                      final companyId = _companyId(c);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withAlpha((0.12 * 255).round()),
                            child: const Icon(
                              Icons.apartment,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(_safe(c["name"])),
                          subtitle: Text(
                            "Email: ${_safe(c["email"])}\nPhone: ${_safe(c["phone"])}\nAddress: ${_safe(c["address"])}\nCompany ID: ${companyId ?? "-"}",
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _openAddOperator(c),
                                child: const Text("Add Operator"),
                              ),
                              IconButton(
                                tooltip: "Edit",
                                onPressed: () => _openEdit(c),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: "Delete",
                                onPressed: () => _deleteCompany(c),
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
