import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../state/conductor_store.dart';

class ConductorHomePage extends StatefulWidget {
  const ConductorHomePage({super.key});

  @override
  State<ConductorHomePage> createState() => _ConductorHomePageState();
}

class _ConductorHomePageState extends State<ConductorHomePage> {
  // palette (from your spec)
  static const _primary = Color(0xFF2563EB);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _text = Color(0xFF0F172A);
  static const _text2 = Color(0xFF475569);
  static const _border = Color(0xFFE2E8F0);

  static const _success = Color(0xFF16A34A);
  static const _warning = Color(0xFFF59E0B);
  static const _danger = Color(0xFFDC2626);
  static const _info = Color(0xFF0EA5E9);
  static const _muted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final date = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await context.read<ConductorStore>().initHome(todayYYYYMMDD: date);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConductorStore>();
    final bus = store.myBus;
    final trips = store.todayTrips;

    final greeting = _greeting(DateTime.now().hour);
    final initials = _initials(bus?.licensePlateNo ?? "");

    // Optional: wire this later to realtime status. For now it won’t crash.
    final connected = (store.wsConnected == true);

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _TopHeader(
                greeting: greeting,
                initials: initials,
                connected: connected,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    if (store.error != null) ...[
                      _errorBanner(store.error!),
                      const SizedBox(height: 12),
                    ],

                    if (bus != null) ...[
                      _busCard(bus, connected: connected),
                      const SizedBox(height: 14),
                    ],

                    if (store.activeTrip != null && store.activeTrip!.isRunning) ...[
                      _activeTripMiniCard(store),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Today's Trips",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
                          ),
                        ),
                        Text(
                          "${trips.length} trips",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (store.loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (trips.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("No trips found for today.", style: TextStyle(color: _text2, fontWeight: FontWeight.w600)),
                      )
                    else
                      ...trips.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _tripCard(context, t),
                          )),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _busCard(dynamic bus, {required bool connected}) {
    final title = bus.licensePlateNo.toString();
    final subtitle = [
      if ((bus.routeNo ?? "").toString().trim().isNotEmpty) "Route ${bus.routeNo}",
      if ((bus.serviceType ?? "").toString().trim().isNotEmpty) bus.serviceType,
      if ((bus.capacity ?? "").toString().trim().isNotEmpty) "${bus.capacity} seats",
    ].join(" • ");

    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primary.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.directions_bus_rounded, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text2)),
                const SizedBox(height: 4),
                Text(bus.companyName.toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _text2)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _pill(
            label: connected ? "Online" : "Offline",
            color: connected ? _success : _warning,
          ),
        ],
      ),
    );
  }

  Widget _activeTripMiniCard(ConductorStore store) {
    final t = store.activeTrip!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(label: "In Progress", color: _info),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
          const SizedBox(height: 10),
          Text("${t.startLocation} → ${t.endLocation}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _text)),
          const SizedBox(height: 6),
          Text("${t.tripDate} • ${_hm(t.departureTime)}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _text2)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.conductorActiveTrip ?? ''),
              child: const Text("View Active Trip", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(BuildContext context, dynamic trip) {
    final status = (trip.status as String).toLowerCase();
    final isRunning = trip.isRunning == true;

    final pill = _pill(label: _statusLabel(status), color: _statusColor(status));

    return _card(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 18, color: _text2),
              const SizedBox(width: 6),
              Text(_hm(trip.departureTime), style: const TextStyle(fontWeight: FontWeight.w900, color: _text)),
              const Spacer(),
              pill,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 18, color: _primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(trip.startLocation, style: const TextStyle(fontWeight: FontWeight.w800, color: _text), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: _muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(trip.endLocation, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, color: _text), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.place_rounded, size: 18, color: _danger),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _primary.withValues(alpha: 0.06),
                foregroundColor: _primary,
                side: BorderSide(color: _primary.withValues(alpha: 0.14)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (isRunning) {
                  Navigator.pushNamed(context, AppRoutes.conductorActiveTrip ?? '');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Trip is ${_statusLabel(status)} (details later)")),
                  );
                }
              },
              child: Text(isRunning ? "View Active Trip" : "View Details", style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // --- small UI helpers (local, no extra files) ---
  static Widget _card({required Widget child, double padding = 16}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }

  static Widget _pill({required String label, required Color color}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
      ),
    );
  }

  static Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _danger.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: _danger, fontSize: 13, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  static String _hm(String s) => s.toString().length >= 5 ? s.toString().substring(0, 5) : s.toString();

  static String _greeting(int hour) {
    if (hour < 12) return "Good Morning, Conductor";
    if (hour < 17) return "Good Afternoon, Conductor";
    return "Good Evening, Conductor";
  }

  static String _initials(String plate) {
    final p = plate.trim();
    if (p.isEmpty) return "RC";
    return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
  }

  static Color _statusColor(String status) {
    switch (status) {
      case "running":
      case "ongoing":
        return _info;
      case "scheduled":
        return _muted;
      case "completed":
        return _success;
      case "cancelled":
        return _danger;
      default:
        return _muted;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case "running":
      case "ongoing":
        return "In Progress";
      case "scheduled":
        return "Upcoming";
      case "completed":
        return "Completed";
      case "cancelled":
        return "Cancelled";
      default:
        return status.isEmpty ? "Unknown" : status;
    }
  }
}

class _TopHeader extends StatelessWidget {
  final String greeting;
  final String initials;
  final bool connected;

  const _TopHeader({
    required this.greeting,
    required this.initials,
    required this.connected,
  });

  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1E40AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primary, _primaryDark]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(26), bottomRight: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting, style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  const Text("Today's Schedule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _ConnDot(connected: connected),
                    const SizedBox(width: 8),
                    Text(connected ? "Online" : "Offline",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnDot extends StatelessWidget {
  final bool connected;
  const _ConnDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    final c = connected ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}
