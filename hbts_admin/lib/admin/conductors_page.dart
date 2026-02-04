import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import 'conductor_form_page.dart';

class ConductorsPage extends StatefulWidget {
  const ConductorsPage({super.key});

  @override
  State<ConductorsPage> createState() => _ConductorsPageState();
}

class _ConductorsPageState extends State<ConductorsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _conductors = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConductors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConductors({String search = ""}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getConductors(search: search);
      if (!mounted) return;
      setState(() {
        _conductors = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  int? _conductorId(Map<String, dynamic> c) {
    final raw = c["conductor_id"] ?? c["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  String? _idCardPreviewUrl(Map<String, dynamic> c) {
    final raw = c["id_card_image_url"]?.toString();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }
    final base = AppConfig.baseUrl.replaceFirst("/api", "");
    return "$base$raw";
  }

  Future<void> _openAddRecord() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConductorFormPage()),
    );
    if (changed == true) {
      await _loadConductors(search: _searchController.text.trim());
    }
  }

  Future<void> _openEdit(Map<String, dynamic> conductor) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConductorFormPage(conductor: conductor),
      ),
    );
    if (changed == true) {
      await _loadConductors(search: _searchController.text.trim());
    }
  }

  Future<void> _deleteConductor(Map<String, dynamic> conductor) async {
    final id = _conductorId(conductor);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete conductor?"),
        content: const Text("Are you sure you want to delete this conductor?"),
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
      await AdminApi.deleteConductor(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conductor deleted")),
      );
      await _loadConductors(search: _searchController.text.trim());
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
        title: const Text("Conductors"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _openAddRecord,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("Add Conductor"),
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
                    _loadConductors(search: value.trim());
                  },
                  decoration: const InputDecoration(
                    hintText: "Search conductor by name or email",
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
            child: _conductors.isEmpty && !_loading
                ? const Center(child: Text("No conductors found"))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _conductors.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = _conductors[index];
                      final conductorId = _conductorId(c);
                      final idCardUrl = _idCardPreviewUrl(c);

                      return Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: idCardUrl == null
                                  ? Container(
                                      color: AppColors.warning
                                          .withAlpha((0.12 * 255).round()),
                                      child: const Icon(
                                        Icons.directions_bus_filled,
                                        color: AppColors.warning,
                                      ),
                                    )
                                  : Image.network(
                                      idCardUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          Container(
                                        color: AppColors.surface,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(_safe(c["name"])),
                          subtitle: Text(
                            "Email: ${_safe(c["email"])}\nID Number: ${_safe(c["id_number"] ?? c["idNumber"])}\nPhone: ${_safe(c["phone"])}\nCompany: ${_safe(c["company"])}\nCompany ID: ${_safe(c["operator_id"])}\nBus ID: ${_safe(c["bus_id"])}\nConductor ID: ${conductorId ?? "-"}",
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: "Edit",
                                onPressed: () => _openEdit(c),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: "Delete",
                                onPressed: () => _deleteConductor(c),
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
