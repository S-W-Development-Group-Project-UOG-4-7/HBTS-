import 'package:flutter/material.dart';

import 'operator_login_page.dart';
import 'services/operator_api.dart';
import 'services/utils/operator_session.dart';



class OperatorDashboardPage extends StatefulWidget {
  final int operatorId;

  const OperatorDashboardPage({super.key, required this.operatorId});

  @override
  State<OperatorDashboardPage> createState() => _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  late Future<Map<String, dynamic>> _operatorFuture;
  late Future<List<dynamic>> _assignedFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _operatorFuture = OperatorApi.fetchOperatorDetails(widget.operatorId);
    _assignedFuture = OperatorApi.fetchAssignedBookings(widget.operatorId);
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  Future<void> _changeStatus(int bookingId, String status) async {
    try {
      await OperatorApi.updateBookingStatus(bookingId: bookingId, status: status);
      setState(() {
        _assignedFuture = OperatorApi.fetchAssignedBookings(widget.operatorId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _logout() {
    OperatorSession.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OperatorLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Operator Dashboard"),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _operatorFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Error loading operator: ${snapshot.error}"),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No operator data"),
                );
              }

              final op = snapshot.data!;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.badge)),
                title: Text(_safeStr(op["name"] ?? OperatorSession.operatorName)),
                subtitle: Text("Email: ${_safeStr(op["email"])}"),
              );
            },
          ),

          const Divider(),

          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _assignedFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No assigned bookings"));
                }

                final bookings = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _assignedFuture = OperatorApi.fetchAssignedBookings(widget.operatorId);
                    });
                  },
                  child: ListView.builder(
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final b = bookings[index] as Map<String, dynamic>;

                      // Adjust these keys to match backend JSON
                      final bookingId = int.tryParse(_safeStr(b["id"])) ?? 0;
                      final pickup = _safeStr(b["pickup"]);
                      final dropoff = _safeStr(b["dropoff"]);
                      final status = _safeStr(b["status"]);
                      final fare = _safeStr(b["fare"]);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.local_taxi),
                          title: Text("$pickup → $dropoff"),
                          subtitle: Text("Status: $status"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Rs. $fare"),
                              const SizedBox(height: 6),
                              PopupMenuButton<String>(
                                onSelected: (s) => _changeStatus(bookingId, s),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: "accepted", child: Text("Accept")),
                                  PopupMenuItem(value: "in_progress", child: Text("Start Trip")),
                                  PopupMenuItem(value: "completed", child: Text("Complete")),
                                ],
                                child: const Icon(Icons.more_vert),
                              ),
                            ],
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
