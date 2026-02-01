import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorRoutesPage extends StatefulWidget {
  const OperatorRoutesPage({super.key});

  @override
  State<OperatorRoutesPage> createState() => _OperatorRoutesPageState();
}

class _OperatorRoutesPageState extends State<OperatorRoutesPage> {
  late Future<List<Map<String, dynamic>>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _routesFuture = OperatorApi.fetchRoutes();
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  Future<void> _showAddRoute() async {
    final nameCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final distanceCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Route"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Route Name"),
              ),
              TextField(
                controller: fromCtrl,
                decoration: const InputDecoration(labelText: "From"),
              ),
              TextField(
                controller: toCtrl,
                decoration: const InputDecoration(labelText: "To"),
              ),
              TextField(
                controller: distanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Distance"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    if (nameCtrl.text.trim().isEmpty ||
        fromCtrl.text.trim().isEmpty ||
        toCtrl.text.trim().isEmpty ||
        distanceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route name, from, to, and distance are required.")),
      );
      return;
    }

    final distance = num.tryParse(distanceCtrl.text.trim());
    if (distance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Distance must be a number.")),
      );
      return;
    }

    try {
      await OperatorApi.createRoute(
        from: fromCtrl.text.trim(),
        to: toCtrl.text.trim(),
        name: nameCtrl.text.trim(),
        distanceKm: distance,
      );
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Routes"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddRoute,
                icon: const Icon(Icons.add),
                label: const Text("Add Route"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _routesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("No routes yet."));
                  }
                  final routes = snapshot.data ?? [];
                  if (routes.isEmpty) {
                    return const Center(child: Text("No routes yet."));
                  }

                  return ListView.builder(
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final r = routes[index];
                      final name = _safeStr(r["route_name"]);
                      final from = _safeStr(r["from_location"]);
                      final to = _safeStr(r["to_location"]);
                      final distance = _safeStr(r["distance_km"]);

                      final title = name != "-" ? name : "$from -> $to";

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.map),
                          title: Text(title),
                          subtitle: Text("From: $from | To: $to | Distance: $distance"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
