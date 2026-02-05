import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'route_card.dart';

class RouteHistoryPage extends StatefulWidget {
  const RouteHistoryPage({super.key});

  @override
  State<RouteHistoryPage> createState() => _RouteHistoryPageState();
}

class _RouteHistoryPageState extends State<RouteHistoryPage> {
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getRouteHistory();
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

  int? _routeId(Map<String, dynamic> route) {
    final raw = route["route_id"] ?? route["routeId"] ?? route["id"];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  Future<void> _restoreRoute(Map<String, dynamic> route) async {
    final id = _routeId(route);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route ID not found")),
      );
      return;
    }
    try {
      await AdminApi.restoreRoute(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route restored")),
      );
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Route History")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: _routes.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text("No deleted routes found")),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _routes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            return RouteCard(
                              route: _routes[index],
                              onRestore: () => _restoreRoute(_routes[index]),
                            );
                          },
                        ),
                ),
    );
  }
}

