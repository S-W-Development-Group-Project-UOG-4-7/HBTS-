import 'package:flutter/material.dart';

import 'operator_assignments_page.dart';
import 'operator_bus_stats_page.dart';
import 'operator_login_page.dart';
import 'operator_platforms_page.dart';
import 'operator_routes_page.dart';
import 'operator_tickets_page.dart';
import 'operator_trips_page.dart';
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
  late Future<List<Map<String, dynamic>>> _assignedFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _operatorFuture = OperatorApi.fetchOperatorDetails();
    _assignedFuture = OperatorApi.fetchAssignedTrips();
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();


  Future<void> _changeTripStatus(int tripId, String status) async {
    try {
      await OperatorApi.updateTripStatus(tripId: tripId, status: status);
      setState(() {
        _assignedFuture = OperatorApi.fetchAssignedTrips();
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "scheduled":
        return Colors.blue.shade600;
      case "delayed":
        return Colors.orange.shade700;
      case "parked":
        return Colors.blueGrey.shade700;
      case "ongoing":
      case "running":
      case "in_progress":
        return Colors.orange.shade700;
      case "completed":
        return Colors.green.shade700;
      case "cancelled":
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Operator Dashboard"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "Logout",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        color: Colors.blue.shade50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OperatorHeaderCard(
                operatorFuture: _operatorFuture,
                fallbackName: OperatorSession.operatorName,
                onRetry: _reload,
              ),
              const SizedBox(height: 20),
              const Text(
                "Operator Tools",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width > 1000
                      ? 4
                      : width > 700
                          ? 3
                          : 2;

                  final actions = [
                    _OperatorAction(
                      title: "Validate Tickets",
                      subtitle: "Lookup and verify tickets",
                      icon: Icons.confirmation_number,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperatorTicketsPage()),
                      ),
                    ),
                    _OperatorAction(
                      title: "Drivers and Buses",
                      subtitle: "View driver and bus details",
                      icon: Icons.assignment_ind,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperatorAssignmentsPage()),
                      ),
                    ),
                    _OperatorAction(
                      title: "Trips and Status",
                      subtitle: "View trip details and status",
                      icon: Icons.list_alt,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperatorTripsPage()),
                      ),
                    ),
                    _OperatorAction(
                      title: "Bus Booking Status",
                      subtitle: "Booking counts per bus",
                      icon: Icons.bar_chart,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperatorBusStatsPage()),
                      ),
                    ),
                    _OperatorAction(
                      title: "Handle Platform Allocation",
                      subtitle: "Platforms and terminals",
                      icon: Icons.schedule,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperatorPlatformsPage()),
                      ),
                    ),
                    _OperatorAction(
                      title: "Manage Routes",
                      subtitle: "Create and edit routes",
                      icon: Icons.map,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperatorRoutesPage()),
                      ),
                    ),
                  ];

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: actions
                        .map((action) => _ActionCard(action: action))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "Assigned Trips",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _AssignedTripsSection(
                tripsFuture: _assignedFuture,
                onRetry: _reload,
                onStatusChange: _changeTripStatus,
                statusColor: _statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperatorHeaderCard extends StatelessWidget {
  final Future<Map<String, dynamic>> operatorFuture;
  final String? fallbackName;
  final VoidCallback onRetry;

  const _OperatorHeaderCard({
    required this.operatorFuture,
    required this.fallbackName,
    required this.onRetry,
  });

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: operatorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _EmptyStateCard(
            title: "Operator Info",
            message: "Failed to load operator details.",
            actionLabel: "Retry",
            onAction: onRetry,
          );
        }
        if (!snapshot.hasData) {
          return _EmptyStateCard(
            title: "Operator Info",
            message: "No operator data available.",
            actionLabel: "Retry",
            onAction: onRetry,
          );
        }

        final op = snapshot.data!;
        final name = _safeStr(op["name"] ?? fallbackName);
        final email = _safeStr(op["email"]);

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blue.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.badge, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Email: $email",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssignedTripsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> tripsFuture;
  final VoidCallback onRetry;
  final Future<void> Function(int, String) onStatusChange;
  final Color Function(String) statusColor;

  const _AssignedTripsSection({
    required this.tripsFuture,
    required this.onRetry,
    required this.onStatusChange,
    required this.statusColor,
  });

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: tripsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _EmptyStateCard(
            title: "Assigned Trips",
            message: "Failed to load assigned trips.",
            actionLabel: "Retry",
            onAction: onRetry,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyStateCard(
            title: "Assigned Trips",
            message: "No assigned trips yet.",
            actionLabel: "Refresh",
            onAction: onRetry,
          );
        }

        final trips = snapshot.data!;
        return Column(
          children: trips.map((trip) {
            final tripId = int.tryParse(_safeStr(trip["trip_id"])) ?? 0;
            final routeName = _safeStr(trip["route_name"]);
            final from = _safeStr(trip["from_location"]);
            final to = _safeStr(trip["to_location"]);
            final status = _safeStr(trip["status"]);
            final bus = _safeStr(trip["license_plate_no"]);
            final driver = _safeStr(trip["driver_name"]);
            final date = _safeStr(trip["trip_date"]);
            final depart = _safeStr(trip["departure_time"]);

            final title = routeName != "-"
                ? routeName
                : ((from != "-" || to != "-")
                    ? "$from -> $to"
                    : "Trip #$tripId");

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Date: $date | Depart: $depart",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Bus: $bus | Driver: $driver",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<String>(
                        onSelected: (s) => onStatusChange(tripId, s),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: "scheduled", child: Text("Set Scheduled")),
                          PopupMenuItem(value: "parked", child: Text("Set Parked")),
                          PopupMenuItem(value: "ongoing", child: Text("Set Ongoing")),
                          PopupMenuItem(value: "delayed", child: Text("Set Delayed")),
                          PopupMenuItem(value: "completed", child: Text("Complete")),
                          PopupMenuItem(value: "cancelled", child: Text("Cancel")),
                        ],
                        child: const Icon(Icons.more_vert),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade50,
              child: Icon(Icons.info, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _OperatorAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OperatorAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _OperatorAction action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.shade50,
                child: Icon(action.icon, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                action.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.subtitle,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
