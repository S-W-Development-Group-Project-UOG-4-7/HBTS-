import 'package:flutter/material.dart';
import '../../services/admin_api.dart';
import 'customer_details_page.dart';

class CustomersDashboard extends StatefulWidget {
  const CustomersDashboard({super.key});

  @override
  State<CustomersDashboard> createState() => _CustomersDashboardState();
}

class _CustomersDashboardState extends State<CustomersDashboard> {
  List<dynamic> _customers = [];
  bool _loading = true;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers({String search = ""}) async {
    setState(() => _loading = true);

    try {
      final data = await AdminApi.getPassengers(search);
      setState(() {
        _customers = data;
      });
    } catch (e) {
      debugPrint("Customer load error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  String _safe(dynamic v) => v == null ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customers")),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search by name",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _search = value.trim();
                _loadCustomers(search: _search);
              },
            ),
          ),

          // 🔄 LOADING
          if (_loading)
            const LinearProgressIndicator(),

          // 📋 LIST
          Expanded(
            child: _customers.isEmpty && !_loading
                ? const Center(child: Text("No customers found"))
                : ListView.separated(
                    itemCount: _customers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user =
                          _customers[index] as Map<String, dynamic>;

                      final int userId =
                          (user["user_id"] as num).toInt();

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(_safe(user["name"])),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_safe(user["email"])),
                            Text("Phone: ${_safe(user["phone"])}"),
                            Text(
                              "Joined: ${_safe(user["created_at"]).toString().split('T')[0]}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailsPage(
                                userId: userId,
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
    );
  }
}
