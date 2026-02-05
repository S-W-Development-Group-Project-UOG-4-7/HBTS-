import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';
import 'route_card.dart';
import 'route_form_page.dart';
import 'route_history_page.dart';
import 'route_search_page.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getRoutes();
      if (!mounted) return;
      setState(() {
        _routes = data.cast<Map<String, dynamic>>();
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
      MaterialPageRoute(builder: (_) => const RouteFormPage()),
    );
    if (changed == true) {
      await _loadRoutes();
    }
  }

  Future<void> _openEdit(Map<String, dynamic> route) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RouteFormPage(route: route)),
    );
    if (changed == true) {
      await _loadRoutes();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RouteHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Routes")),
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
                      MaterialPageRoute(builder: (_) => const RouteSearchPage()),
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
                        onRefresh: _loadRoutes,
                        child: _routes.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text("No routes found")),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _routes.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) => RouteCard(
                                  route: _routes[index],
                                  onTap: () => _openEdit(_routes[index]),
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

