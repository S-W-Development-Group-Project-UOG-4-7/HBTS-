import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'trip_card.dart';
import 'trip_details_page.dart';

class TripSearchPage extends StatefulWidget {
  const TripSearchPage({super.key});

  @override
  State<TripSearchPage> createState() => _TripSearchPageState();
}

class _TripSearchPageState extends State<TripSearchPage> {
  final _tripIdCtrl = TextEditingController();
  final _routeIdCtrl = TextEditingController();
  final _operatorIdCtrl = TextEditingController();
  final _busIdCtrl = TextEditingController();
  final _driverIdCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _tripIdCtrl.dispose();
    _routeIdCtrl.dispose();
    _operatorIdCtrl.dispose();
    _busIdCtrl.dispose();
    _driverIdCtrl.dispose();
    _statusCtrl.dispose();
    _dateCtrl.dispose();
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
      final tripId = _parseInt(_tripIdCtrl.text, "Trip Id");
      final routeId = _parseInt(_routeIdCtrl.text, "Route Id");
      final operatorId = _parseInt(_operatorIdCtrl.text, "Operator Id");
      final busId = _parseInt(_busIdCtrl.text, "Bus Id");
      final driverId = _parseInt(_driverIdCtrl.text, "Driver Id");

      final data = await AdminApi.getTrips(
        tripId: tripId,
        routeId: routeId,
        operatorId: operatorId,
        busId: busId,
        driverId: driverId,
        status: _statusCtrl.text.trim(),
        tripDate: _dateCtrl.text.trim(),
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
    _tripIdCtrl.clear();
    _routeIdCtrl.clear();
    _operatorIdCtrl.clear();
    _busIdCtrl.clear();
    _driverIdCtrl.clear();
    _statusCtrl.clear();
    _dateCtrl.clear();
    setState(() {
      _results = [];
      _error = null;
      _loading = false;
    });
  }

  Future<void> _openDetails(Map<String, dynamic> trip) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailsPage(trip: trip)),
    );
    if (changed == true || changed is Map) {
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
      appBar: AppBar(title: const Text("Search Trips")),
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
                              label: "Trip Id",
                              controller: _tripIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Route Id",
                              controller: _routeIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Operator Id",
                              controller: _operatorIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Bus Id",
                              controller: _busIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Driver Id",
                              controller: _driverIdCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _buildSearchTile(
                              label: "Status",
                              controller: _statusCtrl,
                            ),
                            _buildSearchTile(
                              label: "Trip Date",
                              controller: _dateCtrl,
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
                        ? const Center(child: Text("No trips found"))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) => TripCard(
                              trip: _results[index],
                              onTap: () => _openDetails(_results[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

