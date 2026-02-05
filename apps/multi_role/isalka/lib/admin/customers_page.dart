import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'customer_details_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> passengers = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPassengers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPassengers({String search = ""}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getPassengers(search);
      if (!mounted) return;
      setState(() {
        passengers = data;
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

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customers (Passengers)"),
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _loadPassengers(search: value.trim());
              },
              decoration: const InputDecoration(
                hintText: "Search passenger by name or email",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          if (_loading) const LinearProgressIndicator(),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // 📋 PASSENGER LIST
          Expanded(
            child: passengers.isEmpty && !_loading
                ? const Center(child: Text("No passengers found"))
                : ListView.separated(
                    itemCount: passengers.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p =
                          passengers[index] as Map<String, dynamic>;
                      final int userId =
                          (p["user_id"] as num).toInt();

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(_safe(p["name"])),
                        subtitle: Text(
                          "${_safe(p["email"])} • ${_safe(p["phone"])}",
                        ),
                        trailing:
                            const Icon(Icons.chevron_right),

                        // 🔑 THIS IS THE IMPORTANT FIX
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailsPage(
                                userId: userId,
                              ),
                            ),
                          );

                          // 🔄 RELOAD LIST AFTER RETURN
                          _loadPassengers(
                            search:
                                _searchController.text.trim(),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
