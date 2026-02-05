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
      appBar: AppBar(title: const Text("Search Trips")),
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
                        width: 140,
                        child: _buildSearchField(
                          label: "Trip Id",
                          controller: _tripIdCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _buildSearchField(
                          label: "Route Id",
                          controller: _routeIdCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 160,
                        child: _buildSearchField(
                          label: "Operator Id",
                          controller: _operatorIdCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _buildSearchField(
                          label: "Bus Id",
                          controller: _busIdCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _buildSearchField(
                          label: "Driver Id",
                          controller: _driverIdCtrl,
                          keyboardType: TextInputType.number,
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
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 160,
                        child: _buildSearchField(
                          label: "Trip Date",
                          controller: _dateCtrl,
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

