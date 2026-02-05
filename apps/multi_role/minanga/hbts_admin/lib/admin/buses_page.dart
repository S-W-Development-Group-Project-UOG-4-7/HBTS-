import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'bus_card.dart';
import 'bus_form_page.dart';
import 'bus_history_page.dart';
import 'bus_search_page.dart';
import '../theme/app_theme.dart';

class BusesPage extends StatefulWidget {
  const BusesPage({super.key});

  @override
  State<BusesPage> createState() => _BusesPageState();
}

class _BusesPageState extends State<BusesPage> {
  List<Map<String, dynamic>> _buses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getBuses();
      if (!mounted) return;
      setState(() {
        _buses = data.cast<Map<String, dynamic>>();
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

  Future<void> _openAddRecord() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusFormPage()),
    );
    if (changed == true) {
      await _loadBuses();
    }
  }

  Future<void> _openEdit(Map<String, dynamic> bus) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BusFormPage(bus: bus)),
    );
    if (changed == true) {
      await _loadBuses();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buses")),
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
                      MaterialPageRoute(builder: (_) => const BusSearchPage()),
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
                        onRefresh: _loadBuses,
                        child: _buses.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text("No buses found")),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _buses.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) {
                                  return BusCard(
                                    bus: _buses[index],
                                    onTap: () => _openEdit(_buses[index]),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

