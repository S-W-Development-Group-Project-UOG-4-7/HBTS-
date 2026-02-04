import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'route_card.dart';
import 'route_form_page.dart';

class RouteSearchPage extends StatefulWidget {
  const RouteSearchPage({super.key});

  @override
  State<RouteSearchPage> createState() => _RouteSearchPageState();
}

class _RouteSearchPageState extends State<RouteSearchPage> {
  final _routeIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _routeIdCtrl.dispose();
    _nameCtrl.dispose();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(String raw, String label) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw Exception("Invalid number for $label");
    }
    return parsed;
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final routeId = _parseInt(_routeIdCtrl.text, "Route Id");
      final data = await AdminApi.getRoutes(
        routeId: routeId,
        name: _nameCtrl.text.trim(),
        origin: _originCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        status: _statusCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _results = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _clearAll() {
    _routeIdCtrl.clear();
    _nameCtrl.clear();
    _originCtrl.clear();
    _destinationCtrl.clear();
    _statusCtrl.clear();
    setState(() {
      _results = [];
      _error = null;
      _loading = false;
    });
  }

  Future<void> _openEdit(Map<String, dynamic> route) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RouteFormPage(route: route)),
    );
    if (changed == true) {
      await _search();
    }
  }

  Widget _buildSearchField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Routes")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: _buildSearchField(
                          label: "Route Id",
                          controller: _routeIdCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 220,
                        child: _buildSearchField(
                          label: "Route Name",
                          controller: _nameCtrl,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 200,
                        child: _buildSearchField(
                          label: "Origin",
                          controller: _originCtrl,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 200,
                        child: _buildSearchField(
                          label: "Destination",
                          controller: _destinationCtrl,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 160,
                        child: _buildSearchField(
                          label: "Status",
                          controller: _statusCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: _search,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text("Search"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("Clear"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(child: Text("No routes found"))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) => RouteCard(
                              route: _results[index],
                              onTap: () => _openEdit(_results[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

