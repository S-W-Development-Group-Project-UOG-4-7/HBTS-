import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_routes.dart' as routes;
import '../state/conductor_store.dart';

class ConductorActiveTripPage extends StatefulWidget {
  const ConductorActiveTripPage({super.key});

  @override
  State<ConductorActiveTripPage> createState() => _ConductorActiveTripPageState();
}

class _ConductorActiveTripPageState extends State<ConductorActiveTripPage> {
  // palette
  static const _primary = Color(0xFF2563EB);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _text = Color(0xFF0F172A);
  static const _text2 = Color(0xFF475569);
  static const _border = Color(0xFFE2E8F0);

  static const _success = Color(0xFF16A34A);
  static const _warning = Color(0xFFF59E0B);
  static const _info = Color(0xFF0EA5E9);
  static const _muted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<ConductorStore>();
      await store.refreshActiveTrip();
      await store.loadActiveTripBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConductorStore>();
    final t = store.activeTrip;

    if (t == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(title: const Text("Active Trip")),
        body: const Center(child: Text("No active trip")),
      );
    }

    final list = store.activeTripBookings;
    final boarded = list.where((b) => b.isBoarded).length;
    final cashPending = list.where((b) => b.isCashPending).length;
    final paid = list.where((b) => b.isPaid).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(t.routeName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _chip("RUNNING", _info, Icons.play_circle_fill_rounded)),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => store.loadActiveTripBookings(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${t.startLocation} → ${t.endLocation}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
                  const SizedBox(height: 6),
                  Text("${t.tripDate} • ${_hm(t.departureTime)} → ${_hm(t.arrivalTime)}",
                      style: const TextStyle(color: _text2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _counter("Boarded", boarded, _success)),
                      const SizedBox(width: 10),
                      Expanded(child: _counter("Cash pending", cashPending, _warning)),
                      const SizedBox(width: 10),
                      Expanded(child: _counter("Paid", paid, _info)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
onPressed: () => Navigator.pushNamed(context, routes.AppRoutes.conductorScan ?? ''),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text("Scan QR", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _border),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            // focus search field on bookings tab, or implement search dialog
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.search_rounded),
                          label: const Text("Search", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(store, "all", "All"),
                  _filterChip(store, "not_boarded", "Not boarded"),
                  _filterChip(store, "boarded", "Boarded"),
                  _filterChip(store, "cash_pending", "Cash pending"),
                  _filterChip(store, "paid", "Paid"),
                ],
              ),
            ),
            const SizedBox(height: 12),

            ...list.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _bookingRow(context, b),
            )),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: Text("No bookings")),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(ConductorStore store, String value, String label) {
    final selected = store.bookingFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => store.setBookingFilter(value),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _bookingRow(BuildContext context, dynamic b) {
    final chips = <Widget>[];
    chips.add(_chip(b.isBoarded ? "BOARDED" : "NOT BOARDED", b.isBoarded ? _success : _muted,
        b.isBoarded ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded));

    if (b.isCashPending) {
      chips.add(_chip("CASH PENDING", _warning, Icons.payments_rounded));
    } else if (b.isPaid) {
      chips.add(_chip("PAID", _success, Icons.verified_rounded));
    }

    return _card(
      padding: 14,
      child: InkWell(
onTap: () => Navigator.pushNamed(context, routes.AppRoutes.conductorBookingDetails ?? '', arguments: {"booking": b} as Object),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primary.withValues(alpha: 0.18)),
              ),
              child: Text(b.seatNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.passengerName.isEmpty ? "Passenger" : b.passengerName,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _text)),
                const SizedBox(height: 4),
                Text("${b.boardingStopName} → ${b.droppingStopName}",
                    style: const TextStyle(color: _text2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  static Widget _card({required Widget child, double padding = 16}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }

  static Widget _chip(String label, Color color, IconData icon) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: color)),
      ]),
    );
  }

  static Widget _counter(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _text2, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          Text("$value", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  static String _hm(String s) => s.length >= 5 ? s.substring(0, 5) : s;
}
