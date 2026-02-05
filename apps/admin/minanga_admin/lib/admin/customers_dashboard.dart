import 'package:flutter/material.dart';
import '../../services/admin_api.dart';
import 'customer_details_page.dart';
import '../theme/app_theme.dart';

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
      if (!mounted) return;
      setState(() {
        _customers = data;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint("Customer load error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
      appBar: AppBar(title: const Text("Customers")),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Search by name",
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    _search = value.trim();
                    _loadCustomers(search: _search);
                  },
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _customers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final user =
                          _customers[index] as Map<String, dynamic>;

                      final int userId =
                          (user["user_id"] as num).toInt();

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withAlpha((0.12 * 255).round()),
                            child: const Icon(
                              Icons.person,
                              color: AppColors.primary,
                            ),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


