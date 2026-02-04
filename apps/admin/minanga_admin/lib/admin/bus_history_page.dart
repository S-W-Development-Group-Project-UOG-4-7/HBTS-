import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'bus_card.dart';

class BusHistoryPage extends StatefulWidget {
  const BusHistoryPage({super.key});

  @override
  State<BusHistoryPage> createState() => _BusHistoryPageState();
}

class _BusHistoryPageState extends State<BusHistoryPage> {
  List<Map<String, dynamic>> _buses = [];
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
      final data = await AdminApi.getBusHistory();
      if (!mounted) return;
      setState(() {
        _buses = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _busId(Map<String, dynamic> bus) {
    final raw = bus["bus_id"] ?? bus["busId"] ?? bus["id"];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  Future<void> _restoreBus(Map<String, dynamic> bus) async {
    final id = _busId(bus);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }
    try {
      await AdminApi.restoreBus(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus restored")),
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
      appBar: AppBar(title: const Text("Bus History")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: _buses.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text("No deleted buses found")),
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
                              onRestore: () => _restoreBus(_buses[index]),
                            );
                          },
                        ),
                ),
    );
  }
}

