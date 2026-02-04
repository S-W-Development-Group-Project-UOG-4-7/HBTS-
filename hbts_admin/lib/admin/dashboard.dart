import 'package:flutter/material.dart';
import 'dart:math';
import 'customers_page.dart';
import 'drivers_dashboard.dart';
import 'operators_dashboard.dart';
import 'companies_page.dart';
import 'conductors_page.dart';
import 'buses_page.dart';
import 'routes_page.dart';
import 'trips_page.dart';
import 'report_card_page.dart';
import '../screens/login_page.dart';
import '../screens/signup_page.dart';
import '../services/admin_api.dart';
import '../services/driver_admin_api.dart';
import '../services/token_store.dart';
import '../theme/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  String? _error;
  int _passengerActive = 0;
  int _passengerPending = 0;
  int _passengerRejected = 0;
  int _driverActive = 0;
  int _driverPending = 0;
  int _driverRejected = 0;
  int _ownerActive = 0;
  int _ownerInactive = 0;
  int _ownerSuspended = 0;
  int _busTotal = 0;
  int _routeTotal = 0;
  int _tripTotal = 0;
  List<_ChartSlice> _busSlices = const [];
  List<_ChartSlice> _tripSlices = const [];

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    try {
      final passengersFuture = AdminApi.getPassengers("");
      final approvedDriversFuture =
          DriverAdminApi.list(status: "approved");
      final pendingDriversFuture =
          DriverAdminApi.list(status: "pending");
      final rejectedDriversFuture =
          DriverAdminApi.list(status: "rejected");
      final busesFuture = AdminApi.getBuses();
      final busOwnersFuture = AdminApi.getCompanies();
      final routesFuture = AdminApi.getRoutes();
      final tripsFuture = AdminApi.getTrips();

      final results = await Future.wait([
        passengersFuture,
        approvedDriversFuture,
        pendingDriversFuture,
        rejectedDriversFuture,
        busesFuture,
        busOwnersFuture,
        routesFuture,
        tripsFuture,
      ]);

      final passengers = results[0];
      final approvedDrivers = results[1];
      final pendingDrivers = results[2];
      final rejectedDrivers = results[3];
      final buses = results[4];
      final busOwners = results[5];
      final routes = results[6];
      final trips = results[7];

      final passengerCounts = _countPassengerStatuses(passengers);
      final busSlices = _buildBusSlices(buses);
      final tripSlices = _buildTripSlices(trips);
      final ownerCounts = _countOwnerStatuses(busOwners);

      if (!mounted) return;
      setState(() {
        _passengerActive = passengerCounts.active;
        _passengerPending = passengerCounts.pending;
        _passengerRejected = passengerCounts.rejected;
        _driverActive = approvedDrivers.length;
        _driverPending = pendingDrivers.length;
        _driverRejected = rejectedDrivers.length;
        _ownerActive = ownerCounts.active;
        _ownerInactive = ownerCounts.inactive;
        _ownerSuspended = ownerCounts.suspended;
        _busTotal = buses.length;
        _routeTotal = routes.length;
        _tripTotal = trips.length;
        _busSlices = busSlices;
        _tripSlices = tripSlices;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  _StatusCounts _countPassengerStatuses(List<dynamic> passengers) {
    var active = 0;
    var pending = 0;
    var rejected = 0;

    for (final item in passengers) {
      if (item is! Map<String, dynamic>) {
        active += 1;
        continue;
      }
      final status = _normalizeStatus(
        item["status"] ??
            item["verification_status"] ??
            item["approval_status"],
      );
      if (status == "pending") {
        pending += 1;
      } else if (status == "rejected") {
        rejected += 1;
      } else {
        active += 1;
      }
    }

    return _StatusCounts(
      active: active,
      pending: pending,
      rejected: rejected,
    );
  }

  String _normalizeStatus(dynamic status) {
    final value = status?.toString().toLowerCase().trim() ?? "";
    if (value.contains("pend")) return "pending";
    if (value.contains("reject") || value.contains("block")) return "rejected";
    if (value.contains("active") ||
        value.contains("approve") ||
        value.contains("verify")) {
      return "active";
    }
    return value.isEmpty ? "active" : value;
  }

  List<_ChartSlice> _buildBusSlices(List<dynamic> buses) {
    final counts = <String, int>{};
    for (final item in buses) {
      if (item is! Map<String, dynamic>) continue;
      final type = item["service_type"]?.toString().trim();
      if (type == null || type.isEmpty) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const colors = [
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.primary,
      AppColors.primarySoft,
      AppColors.accent,
    ];

    return [
      for (var i = 0; i < sorted.length; i++)
        _ChartSlice(
          label: sorted[i].key,
          value: sorted[i].value,
          color: colors[i % colors.length],
        ),
    ];
  }

  List<_ChartSlice> _buildTripSlices(List<dynamic> trips) {
    final counts = <String, int>{};
    for (final item in trips) {
      if (item is! Map<String, dynamic>) continue;
      final status = item["status"]?.toString().trim().toLowerCase();
      final label = (status == null || status.isEmpty) ? "scheduled" : status;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return [
      _ChartSlice(
        label: "scheduled",
        value: counts["scheduled"] ?? 0,
        color: AppColors.warning,
      ),
      _ChartSlice(
        label: "running",
        value: counts["in_progress"] ?? 0,
        color: AppColors.accent,
      ),
      _ChartSlice(
        label: "completed",
        value: counts["completed"] ?? 0,
        color: AppColors.success,
      ),
      _ChartSlice(
        label: "cancelled",
        value: counts["cancelled"] ?? 0,
        color: AppColors.danger,
      ),
    ];
  }

  _OwnerCounts _countOwnerStatuses(List<dynamic> owners) {
    var active = 0;
    var inactive = 0;
    var suspended = 0;

    for (final item in owners) {
      if (item is! Map<String, dynamic>) continue;
      final status =
          item["status"]?.toString().toLowerCase().trim() ?? "active";
      if (status == "active") {
        active += 1;
      } else if (status == "suspended") {
        suspended += 1;
      } else {
        inactive += 1;
      }
    }

    return _OwnerCounts(
      active: active,
      inactive: inactive,
      suspended: suspended,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPassengers =
        _passengerActive + _passengerPending + _passengerRejected;
    final totalDrivers = _driverActive + _driverPending + _driverRejected;
    final totalOwners = _ownerActive + _ownerInactive + _ownerSuspended;
    final runningTrips = _sliceValue(_tripSlices, "running");
    final completedTrips = _sliceValue(_tripSlices, "completed");
    final revenueSlices = _busSlices.isNotEmpty
        ? _busSlices
        : [
            const _ChartSlice(
              label: "City",
              value: 42,
              color: AppColors.danger,
            ),
            const _ChartSlice(
              label: "Express",
              value: 31,
              color: AppColors.primary,
            ),
            const _ChartSlice(
              label: "Intercity",
              value: 27,
              color: AppColors.accent,
            ),
          ];
    final statCards = [
      _StatCardData(
        title: "Passengers",
        value: _formatNumber(totalPassengers),
        subtitle: "Active: ${_formatNumber(_passengerActive)}",
        footer:
            "Pending: ${_formatNumber(_passengerPending)} · Rejected: ${_formatNumber(_passengerRejected)}",
        color: const Color(0xFFF59E0B),
        icon: Icons.people_outline,
      ),
      _StatCardData(
        title: "Drivers",
        value: _formatNumber(totalDrivers),
        subtitle: "Approved: ${_formatNumber(_driverActive)}",
        footer:
            "Pending: ${_formatNumber(_driverPending)} · Rejected: ${_formatNumber(_driverRejected)}",
        color: const Color(0xFFF43F5E),
        icon: Icons.badge_outlined,
      ),
      _StatCardData(
        title: "Bus Operators",
        value: _formatNumber(totalOwners),
        subtitle: "Active: ${_formatNumber(_ownerActive)}",
        footer:
            "Inactive: ${_formatNumber(_ownerInactive)} · Suspended: ${_formatNumber(_ownerSuspended)}",
        color: const Color(0xFF10B981),
        icon: Icons.business_center_outlined,
      ),
      _StatCardData(
        title: "Buses",
        value: _formatNumber(_busTotal),
        subtitle: "Routes: ${_formatNumber(_routeTotal)}",
        footer: "Trips: ${_formatNumber(_tripTotal)}",
        color: AppColors.primary,
        icon: Icons.directions_bus_outlined,
      ),
    ];
    final trafficSources = [
      _TrafficSourceData(
        label: "Passengers Active",
        value: _ratio(_passengerActive, totalPassengers),
      ),
      _TrafficSourceData(
        label: "Passengers Pending",
        value: _ratio(_passengerPending, totalPassengers),
      ),
      _TrafficSourceData(
        label: "Drivers Approved",
        value: _ratio(_driverActive, totalDrivers),
      ),
      _TrafficSourceData(
        label: "Trips Running",
        value: _ratio(runningTrips, _tripTotal),
      ),
      _TrafficSourceData(
        label: "Trips Completed",
        value: _ratio(completedTrips, _tripTotal),
      ),
    ];
    final navItems = [
      _NavItem(
        label: "Dashboard",
        icon: Icons.home_outlined,
        pageBuilder: (_) => const AdminDashboard(),
      ),
      _NavItem(
        label: "Passengers",
        icon: Icons.people_outline,
        pageBuilder: (_) => const CustomersPage(),
      ),
      _NavItem(
        label: "Drivers",
        icon: Icons.badge_outlined,
        pageBuilder: (_) => const DriversDashboard(),
      ),
      _NavItem(
        label: "Bus Operators",
        icon: Icons.business_center_outlined,
        pageBuilder: (_) => const OperatorsDashboard(),
      ),
      _NavItem(
        label: "Companies",
        icon: Icons.apartment_outlined,
        pageBuilder: (_) => const CompaniesPage(),
      ),
      _NavItem(
        label: "Conductors",
        icon: Icons.directions_bus_filled,
        pageBuilder: (_) => const ConductorsPage(),
      ),
      _NavItem(
        label: "Buses",
        icon: Icons.directions_bus_outlined,
        pageBuilder: (_) => const BusesPage(),
      ),
      _NavItem(
        label: "Routes",
        icon: Icons.alt_route_outlined,
        pageBuilder: (_) => const RoutesPage(),
      ),
      _NavItem(
        label: "Trips",
        icon: Icons.route_outlined,
        pageBuilder: (_) => const TripsPage(),
      ),
      _NavItem(
        label: "Reports",
        icon: Icons.picture_as_pdf_outlined,
        pageBuilder: (_) => ReportCardPage(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final sidebar = _Sidebar(
          activeIndex: 0,
          onTap: (index) {
            final pageBuilder = navItems[index].pageBuilder;
            if (pageBuilder == null) return;
            if (index == 0) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: pageBuilder),
            );
          },
          navItems: navItems,
        );
        return Scaffold(
          key: _scaffoldKey,
          appBar: _DashboardAppBar(
            showMenu: !isWide,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            onAddAdmin: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignupScreen(allowSignup: true),
                ),
              );
            },
            onLogout: () async {
              await TokenStore.clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
          drawer: isWide ? null : Drawer(child: sidebar),
          body: Row(
            children: [
              if (isWide) sidebar,
              Expanded(
                child: _DashboardBody(
                  loading: _loading,
                  error: _error,
                  statCards: statCards,
                  revenueSlices: revenueSlices,
                  trafficSources: trafficSources,
                  totalTrips: _tripTotal,
                  runningTrips: runningTrips,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final index = digits.length - i;
    buffer.write(digits[i]);
    if (index > 1 && index % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

int _sliceValue(List<_ChartSlice> slices, String label) {
  for (final slice in slices) {
    if (slice.label == label) return slice.value;
  }
  return 0;
}

double _ratio(int value, int total) {
  if (total <= 0) return 0;
  return value / total;
}

class _NavItem {
  final String label;
  final IconData icon;
  final WidgetBuilder? pageBuilder;

  const _NavItem({
    required this.label,
    required this.icon,
    this.pageBuilder,
  });
}

class _DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showMenu;
  final VoidCallback onMenuTap;
  final VoidCallback onAddAdmin;
  final VoidCallback onLogout;

  const _DashboardAppBar({
    required this.showMenu,
    required this.onMenuTap,
    required this.onAddAdmin,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 12,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          if (showMenu)
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu_rounded),
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_bus_filled,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text("HBTS+ Admin"),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ElevatedButton.icon(
            onPressed: onAddAdmin,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text("Add Admin"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text(
            "Logout",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> navItems;

  const _Sidebar({
    required this.activeIndex,
    required this.onTap,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            Text(
              "HBTS",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              navItems.length,
              (index) => _SidebarItem(
                label: navItems[index].label,
                icon: navItems[index].icon,
                selected: index == activeIndex,
                onTap: () => onTap(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8EDFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_StatCardData> statCards;
  final List<_ChartSlice> revenueSlices;
  final List<_TrafficSourceData> trafficSources;
  final int totalTrips;
  final int runningTrips;

  const _DashboardBody({
    required this.loading,
    required this.error,
    required this.statCards,
    required this.revenueSlices,
    required this.trafficSources,
    required this.totalTrips,
    required this.runningTrips,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "HBTS Admin Dashboard",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            "Operational overview across passengers, drivers, buses, and trips",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          if (loading) const LinearProgressIndicator(),
          if (error != null && !loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.danger),
              ),
            ),
          _StatCardGrid(cards: statCards),
          const SizedBox(height: 16),
          _AnalyticsGrid(
            revenueSlices: revenueSlices,
            trafficSources: trafficSources,
            totalTrips: totalTrips,
            runningTrips: runningTrips,
          ),
          const SizedBox(height: 16),
          _MiniStatsRow(),
        ],
      ),
    );
  }
}

class _StatCardData {
  final String title;
  final String value;
  final String subtitle;
  final String footer;
  final Color color;
  final IconData icon;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.footer,
    required this.color,
    required this.icon,
  });
}

class _StatCardGrid extends StatelessWidget {
  final List<_StatCardData> cards;

  const _StatCardGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 900
                ? 2
                : 1;
        final spacing = 12.0;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final cardWidth = (width - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _StatCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.value,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: data.color,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: data.color.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: data.color),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data.footer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Icon(Icons.trending_up, color: Colors.white, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsGrid extends StatelessWidget {
  final List<_ChartSlice> revenueSlices;
  final List<_TrafficSourceData> trafficSources;
  final int totalTrips;
  final int runningTrips;

  const _AnalyticsGrid({
    required this.revenueSlices,
    required this.trafficSources,
    required this.totalTrips,
    required this.runningTrips,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 1200;
        final spacing = 12.0;
        final cardWidth = isWide ? (width - spacing * 2) / 3 : width;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SalesCard(
                totalTrips: totalTrips,
                runningTrips: runningTrips,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _RevenueCard(slices: revenueSlices),
            ),
            SizedBox(
              width: cardWidth,
              child: _TrafficSourcesCard(sources: trafficSources),
            ),
          ],
        );
      },
    );
  }
}

class _SalesCard extends StatelessWidget {
  final int totalTrips;
  final int runningTrips;

  const _SalesCard({
    required this.totalTrips,
    required this.runningTrips,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Trips Per Day",
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.show_chart, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "3%",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  height: 120,
                  child: _LineChart(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatNumber(totalTrips),
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Total Trips",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatNumber(runningTrips),
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Running Trips",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> points = const [0.4, 0.3, 0.5, 0.35, 0.65, 0.45];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.quadraticBezierTo(
          size.width * ((i - 0.5) / (points.length - 1)),
          size.height * (1 - points[i - 1]),
          x,
          y,
        );
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RevenueCard extends StatelessWidget {
  final List<_ChartSlice> slices;

  const _RevenueCard({required this.slices});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bus Types",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: _InteractiveDonutChart(
                size: 140,
                slices: slices,
                onSliceTap: () {},
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: slices
                  .map(
                    (slice) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _LegendDot(label: slice.label, color: slice.color),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _TrafficSourceData {
  final String label;
  final double value;

  const _TrafficSourceData({required this.label, required this.value});
}

class _TrafficSourcesCard extends StatelessWidget {
  final List<_TrafficSourceData> sources;

  const _TrafficSourcesCard({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Status Overview",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ...sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrafficSourceRow(source: source),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficSourceRow extends StatelessWidget {
  final _TrafficSourceData source;

  const _TrafficSourceRow({required this.source});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              source.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              "${(source.value * 100).round()}%",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: source.value,
            minHeight: 6,
            backgroundColor: AppColors.outline,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _MiniStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 800;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isWide ? (width - 12) / 2 : width,
              child: _MiniStatCard(
                label: "REALTY",
                value: "-0.99",
                color: AppColors.danger,
              ),
            ),
            SizedBox(
              width: isWide ? (width - 12) / 2 : width,
              child: _MiniStatCard(
                label: "INFRA",
                value: "-7.66",
                color: AppColors.success,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCounts {
  final int active;
  final int pending;
  final int rejected;

  const _StatusCounts({
    required this.active,
    required this.pending,
    required this.rejected,
  });
}

class _OwnerCounts {
  final int active;
  final int inactive;
  final int suspended;

  const _OwnerCounts({
    required this.active,
    required this.inactive,
    required this.suspended,
  });
}


class _ChartSlice {
  final String label;
  final int value;
  final Color color;

  const _ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _InteractiveDonutChart extends StatelessWidget {
  final double size;
  final List<_ChartSlice> slices;
  final VoidCallback onSliceTap;

  const _InteractiveDonutChart({
    required this.size,
    required this.slices,
    required this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (_hitSlice(details.localPosition)) {
          onSliceTap();
        }
      },
      child: CustomPaint(
        size: Size(size, size),
        painter: _InteractiveDonutPainter(slices: slices),
      ),
    );
  }

  bool _hitSlice(Offset position) {
    final center = Offset(size / 2, size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance < size * 0.22 || distance > size * 0.48) {
      return false;
    }
    final total = slices.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) return false;
    return true;
  }
}

class _InteractiveDonutPainter extends CustomPainter {
  final List<_ChartSlice> slices;

  _InteractiveDonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final total = slices.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) {
      stroke.color = AppColors.outline;
      canvas.drawCircle(center, radius - 6, stroke);
      return;
    }

    var startAngle = -pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * pi * 2;
      if (sweep <= 0) continue;
      stroke.color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        startAngle,
        sweep,
        false,
        stroke,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _InteractiveDonutPainter oldDelegate) {
    if (oldDelegate.slices.length != slices.length) return true;
    for (var i = 0; i < slices.length; i++) {
      if (oldDelegate.slices[i].value != slices[i].value) return true;
    }
    return false;
  }
}

