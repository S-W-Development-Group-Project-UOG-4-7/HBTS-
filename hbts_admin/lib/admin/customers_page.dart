import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'customer_details_page.dart';
import '../theme/app_theme.dart';

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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _loadPassengers(search: value.trim());
                  },
                  decoration: const InputDecoration(
                    hintText: "Search passenger by name or email",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: passengers.isEmpty && !_loading
                ? const Center(child: Text("No passengers found"))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: passengers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p =
                          passengers[index] as Map<String, dynamic>;
                      final int userId =
                          (p["user_id"] as num).toInt();

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
                          title: Text(_safe(p["name"])),
                          subtitle: Text(
                            "${_safe(p["email"])}  -  ${_safe(p["phone"])}",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailsPage(
                                  userId: userId,
                                ),
                              ),
                            );
                            _loadPassengers(
                              search: _searchController.text.trim(),
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


