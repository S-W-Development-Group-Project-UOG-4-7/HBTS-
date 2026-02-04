import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorPlatformsPage extends StatefulWidget {
  const OperatorPlatformsPage({super.key});

  @override
  State<OperatorPlatformsPage> createState() => _OperatorPlatformsPageState();
}

class _OperatorPlatformsPageState extends State<OperatorPlatformsPage> {
  late Future<List<Map<String, dynamic>>> _platformsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _platformsFuture = OperatorApi.fetchPlatforms();
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  Future<void> _showAddPlatform() async {
    final numberCtrl = TextEditingController();
    final terminalCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Platform"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Platform Number"),
              ),
              TextField(
                controller: terminalCtrl,
                decoration: const InputDecoration(labelText: "Terminal"),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
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

    if (!mounted) return;
    if (created != true) return;

    if (terminalCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terminal and name are required.")),
      );
      return;
    }

    final number = int.tryParse(numberCtrl.text.trim());
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Platform number must be a number.")),
      );
      return;
    }

    try {
      await OperatorApi.createPlatform(
        platformNumber: number,
        terminalName: terminalCtrl.text.trim().isEmpty ? null : terminalCtrl.text.trim(),
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "occupied":
        return Colors.orange.shade700;
      case "reserved":
        return Colors.blue.shade700;
      case "maintenance":
        return Colors.red.shade600;
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Platform Allocation"),
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
                onPressed: _showAddPlatform,
                icon: const Icon(Icons.add),
                label: const Text("Add Platform"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _platformsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  final platforms = snapshot.data ?? [];
                  if (platforms.isEmpty) {
                    return const Center(child: Text("No platforms available."));
                  }

                  return ListView.builder(
                    itemCount: platforms.length,
                    itemBuilder: (context, index) {
                      final p = platforms[index];
                      final number = _safeStr(p["platform_number"]);
                      final terminal = _safeStr(p["terminal_name"]);
                      final name = _safeStr(p["name"]);
                      final status = _safeStr(p["status"]);
                      final currentTrip = _safeStr(p["current_trip_id"]);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                            child: Icon(Icons.place, color: _statusColor(status)),
                          ),
                          title: Text("Platform $number - $name"),
                          subtitle: Text("Terminal: $terminal | Trip: $currentTrip"),
                          trailing: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
