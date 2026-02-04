import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'bus_card.dart';
import 'bus_form_page.dart';

class BusSearchPage extends StatefulWidget {
  const BusSearchPage({super.key});

  @override
  State<BusSearchPage> createState() => _BusSearchPageState();
}

class _BusSearchPageState extends State<BusSearchPage> {
  final _busIdCtrl = TextEditingController();
  final _operatorIdCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _serviceTypeCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _busIdCtrl.dispose();
    _operatorIdCtrl.dispose();
    _plateCtrl.dispose();
    _routeCtrl.dispose();
    _capacityCtrl.dispose();
    _serviceTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final busId = _parseInt(_busIdCtrl.text, "Bus Id");
      final operatorId = _parseInt(_operatorIdCtrl.text, "Bus Operator Id");
      final capacity = _parseInt(_capacityCtrl.text, "Capacity");

      final data = await AdminApi.getBuses(
        busId: busId,
        operatorId: operatorId,
        licensePlateNo: _plateCtrl.text.trim(),
        routeNo: _routeCtrl.text.trim(),
        capacity: capacity,
        serviceType: _serviceTypeCtrl.text.trim(),
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

  int? _parseInt(String raw, String label) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw Exception("Invalid number for $label");
    }
    return parsed;
  }

  void _clearAll() {
    _busIdCtrl.clear();
    _operatorIdCtrl.clear();
    _plateCtrl.clear();
    _routeCtrl.clear();
    _capacityCtrl.clear();
    _serviceTypeCtrl.clear();
    setState(() {
      _results = [];
      _error = null;
      _loading = false;
    });
  }

  Future<void> _openEdit(Map<String, dynamic> bus) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BusFormPage(bus: bus)),
    );
    if (changed == true) {
      await _search();
    }
  }

  Widget _buildSearchTile({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: _search,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text("Search"),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Buses")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width < 640
                            ? 1
                            : width < 980
                                ? 2
                                : 3;
                        final aspect = width < 640
                            ? 4.6
                            : width < 980
                                ? 4.2
                                : 3.8;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: aspect,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildSearchTile(
                              label: "Bus Id",
                              controller: _busIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Bus Operator Id",
                              controller: _operatorIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "License Plate Number",
                              controller: _plateCtrl,
                            ),
                            _buildSearchTile(
                              label: "Route",
                              controller: _routeCtrl,
                            ),
                            _buildSearchTile(
                              label: "Capacity",
                              controller: _capacityCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Service Type",
                              controller: _serviceTypeCtrl,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 34,
                        child: OutlinedButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Clear & Refresh"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            minimumSize: const Size(140, 34),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                        ? const Center(child: Text("No buses found"))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) =>
                                BusCard(
                                  bus: _results[index],
                                  onTap: () => _openEdit(_results[index]),
                                ),
                          ),
          ),
        ],
      ),
    );
  }
}

