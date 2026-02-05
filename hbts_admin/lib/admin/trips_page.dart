import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'trip_card.dart';
import 'trip_details_page.dart';
import 'trip_form_page.dart';
import 'trip_history_page.dart';
import 'trip_search_page.dart';
import '../theme/app_theme.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getTrips();
      if (!mounted) return;
      setState(() {
        _trips = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddRecord() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripFormPage()),
    );
    if (changed == true || changed is Map) {
      await _loadTrips();
    }
  }

  Future<void> _openDetails(Map<String, dynamic> trip) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailsPage(trip: trip)),
    );
    if (changed == true || changed is Map) {
      await _loadTrips();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trips")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TripSearchPage()),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text("Search"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: ElevatedButton.icon(
                    onPressed: _openAddRecord,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Add Record"),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton.icon(
                    onPressed: _openHistory,
                    icon: const Icon(Icons.history),
                    label: const Text("History"),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _loadTrips,
                        child: _trips.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text("No trips found")),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _trips.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) => TripCard(
                                  trip: _trips[index],
                                  onTap: () => _openDetails(_trips[index]),
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

