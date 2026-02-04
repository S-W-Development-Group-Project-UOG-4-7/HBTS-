import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class OperatorsDashboard extends StatefulWidget {
  const OperatorsDashboard({super.key});

  @override
  State<OperatorsDashboard> createState() => _OperatorsDashboardState();
}

class _OperatorsDashboardState extends State<OperatorsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _owners = [];
  bool _loading = true;
  String? _error;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOwners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminApi.getBusOwners();
      if (!mounted) return;
      setState(() {
        _owners = data.cast<Map<String, dynamic>>();
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

  List<Map<String, dynamic>> _filtered(String status) {
    return _owners.where((op) {
      final matchesStatus = op["status"] == status;
      final matchesSearch = _search.isEmpty ||
          op["name"]
              .toString()
          .toLowerCase()
          .contains(_search.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Operators Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Inactive"),
            Tab(text: "Suspended"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search bus operator...",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _loadOwners,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _OperatorList(
                              operators: _filtered("active"),
                              badgeColor: AppColors.success,
                            ),
                            _OperatorList(
                              operators: _filtered("inactive"),
                              badgeColor: AppColors.warning,
                            ),
                            _OperatorList(
                              operators: _filtered("suspended"),
                              badgeColor: AppColors.danger,
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OperatorList extends StatelessWidget {
  const _OperatorList({
    required this.operators,
    required this.badgeColor,
  });

  final List<Map<String, dynamic>> operators;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    if (operators.isEmpty) {
      return const Center(child: Text("No bus operators found"));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: operators.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final op = operators[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withAlpha((0.15 * 255).round()),
              child: Icon(Icons.apartment, color: badgeColor),
            ),
            title: Text(
              op["name"],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Fleet size: ${op["fleet_size"] ?? 0}"),
                Text("Drivers: ${op["drivers"] ?? 0}"),
                Text("Phone: ${op["phone"] ?? "-"}"),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                op["status"].toString().toUpperCase(),
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


