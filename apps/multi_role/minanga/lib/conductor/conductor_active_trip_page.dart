import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../state/conductor_store.dart';
import '../services/conductor_api.dart';
import '../models/conductor_booking_model.dart';

class ConductorActiveTripPage extends StatefulWidget {
  const ConductorActiveTripPage({super.key});

  @override
  State<ConductorActiveTripPage> createState() => _ConductorActiveTripPageState();
}

class _ConductorActiveTripPageState extends State<ConductorActiveTripPage>
    with WidgetsBindingObserver {
  // ---- Design tokens (your palette) ----
  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1E40AF);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Color(0xFFFFFFFF);
  static const _text = Color(0xFF0F172A);
  static const _text2 = Color(0xFF475569);
  static const _border = Color(0xFFE2E8F0);

  static const _success = Color(0xFF16A34A);
  static const _warning = Color(0xFFF59E0B);
  static const _danger = Color(0xFFDC2626);
  static const _info = Color(0xFF0EA5E9);
  static const _muted = Color(0xFF94A3B8);

  StreamSubscription? _tripEvSub;

  bool _loading = true;
  String? _error;

  List<ConductorBooking> _all = const [];
  final int _page = 1;
  final int _limit = 60;

  // filters (wireframe chips)
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ensure ws is started (in case not started on home)
      context.read<ConductorStore>().startRealtime();

      // listen for trip end/cancel
      _tripEvSub = context.read<ConductorStore>().tripEvents.listen((ev) {
        if (!mounted) return;
        if (ev.isTripEnded || ev.isTripCancelled) {
          _showTripEndedDialog(ev.type);
        }
      });

      await _reloadAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripEvSub?.cancel();
    super.dispose();
  }

  // Called when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumeRefresh();
    }
  }

  Future<void> _onResumeRefresh() async {
    // Requirement: call GET /me/active-trip on resume
    await context.read<ConductorStore>().refreshActiveTrip();
    if (!mounted) return;

    // also reload bookings to ensure source of truth
    await _reloadBookings();
  }

  Future<void> _reloadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<ConductorStore>().refreshActiveTrip();
      await _reloadBookings();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadBookings() async {
    final store = context.read<ConductorStore>();
    final trip = store.activeTrip;

    if (trip == null) {
      setState(() {
        _all = const [];
      });
      return;
    }

    final list = await ConductorApi.getTripBookings(
      tripId: trip.tripId,
      page: _page,
      limit: _limit,
    );

    setState(() {
      _all = list;
    });
  }

  List<ConductorBooking> get _filtered {
    final all = _all;
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.notBoarded:
        return all.where((b) => !b.isBoarded).toList();
      case _Filter.boarded:
        return all.where((b) => b.isBoarded).toList();
      case _Filter.cashPending:
        return all.where((b) => b.isCashPending).toList();
      case _Filter.paid:
        return all.where((b) => b.isPaid).toList();
    }
  }

  int get _boardedCount => _all.where((b) => b.isBoarded).length;
  int get _paidCount => _all.where((b) => b.isPaid).length;
  int get _cashPendingCount => _all.where((b) => b.isCashPending).length;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConductorStore>();
    final trip = store.activeTrip;

    if (trip == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Active Trip",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _connPill(connected: store.wsConnected),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "No Active Trip",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _text),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "There is no running trip right now.",
                      style: TextStyle(color: _text2, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(_primaryDark.withValues(alpha: 0.14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Back", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) _errorBanner(_error!),
              const SizedBox.shrink(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Active Trip",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _connPill(connected: store.wsConnected),
          ),
          IconButton(
            tooltip: "Bookings",
            onPressed: () {
              final tripId = context.read<ConductorStore>().activeTrip?.tripId;
              if (tripId == null) return;

              Navigator.pushNamed(
                context,
                AppRoutes.conductorBookings,
                arguments: {"tripId": tripId},
              );
            },
            icon: const Icon(Icons.list_alt_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          children: [
            // Sticky-like header card (wireframe vibe)
            _tripHeader(trip),
            const SizedBox(height: 14),

            // counters
            _countersRow(),
            const SizedBox(height: 14),

            // filter chips
            _filters(),
            const SizedBox(height: 12),

            if (_loading) _thinLoader(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _errorBanner(_error!),
            ],
            const SizedBox(height: 10),

            // bookings list
            ..._buildBookingList(trip.tripId),
          ],
        ),
      ),
    );
  }

  Widget _tripHeader(dynamic trip) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _info.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _info.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.route_rounded, color: _info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusPill(label: "RUNNING", color: _info),
                const SizedBox(height: 10),
                Text(
                  "${trip.startLocation}  →  ${trip.endLocation}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
                ),
                const SizedBox(height: 6),
                Text(
                  "${_hm(trip.departureTime)} • ${trip.tripDate}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countersRow() {
    return Row(
      children: [
        Expanded(child: _counterCard("Boarded", _boardedCount, _success, Icons.check_circle_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _counterCard("Cash Pending", _cashPendingCount, _warning, Icons.payments_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _counterCard("Paid", _paidCount, _success, Icons.verified_rounded)),
      ],
    );
  }

  Widget _counterCard(String label, int value, Color color, IconData icon) {
    return _card(
      padding: 12,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$value",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _text),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _text2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip(_Filter.all, "All"),
        _chip(_Filter.notBoarded, "Not boarded"),
        _chip(_Filter.boarded, "Boarded"),
        _chip(_Filter.cashPending, "Cash pending"),
        _chip(_Filter.paid, "Paid"),
      ],
    );
  }

  Widget _chip(_Filter f, String label) {
    final selected = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _primary.withValues(alpha: 0.14) : _surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _primary.withValues(alpha: 0.22) : _border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _primary : _text2,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBookingList(int tripId) {
    final list = _filtered;

    if (!_loading && list.isEmpty) {
      return [
        _card(
          child: const Text(
            "No bookings found for this filter.",
            style: TextStyle(color: _text2, fontWeight: FontWeight.w800),
          ),
        ),
      ];
    }

    return list.map((b) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _bookingRow(tripId, b),
    )).toList();
  }

  Widget _bookingRow(int tripId, ConductorBooking b) {
    final paidChip = b.isPaid
        ? _statusPill(label: "PAID", color: _success)
        : (b.isCashPending ? _statusPill(label: "CASH", color: _warning) : _statusPill(label: "PENDING", color: _warning));

    final boardChip = b.isBoarded ? _statusPill(label: "BOARDED", color: _success) : _statusPill(label: "NOT BOARDED", color: _danger);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openBookingSheet(tripId, b),
      child: _card(
        padding: 14,
        child: Row(
          children: [
            // big seat label
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primary.withValues(alpha: 0.18)),
              ),
              child: Center(
                child: Text(
                  b.seatNumber,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _primary),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.passengerName.isEmpty ? "Passenger" : b.passengerName,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _text, fontSize: 14.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${b.boardingStopName} → ${b.droppingStopName}",
                    style: const TextStyle(color: _text2, fontWeight: FontWeight.w700, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [paidChip, boardChip],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookingSheet(int tripId, ConductorBooking b) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final canBoard = !b.isBoarded;
        final canCollectCash = b.isCashPending;

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Seat ${b.seatNumber}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
                      ),
                    ),
                    _statusPill(
                      label: b.isPaid ? "PAID" : (b.isCashPending ? "CASH PENDING" : "PENDING"),
                      color: b.isPaid ? _success : _warning,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _kv("Passenger", b.passengerName),
                _kv("Phone", b.passengerPhone),
                _kv("Stops", "${b.boardingStopName} → ${b.droppingStopName}"),
                _kv("Price", "LKR ${b.price.toStringAsFixed(0)}"),
                const SizedBox(height: 14),

                if (!canBoard && !canCollectCash)
                  _infoBanner("Already boarded / payment complete.")
                else
                  Row(
                    children: [
                      if (canBoard)
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ).copyWith(
                                overlayColor: WidgetStateProperty.all(_primaryDark.withValues(alpha: 0.14)),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _markBoarded(tripId, b.bookingId);
                              },
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text("Mark Boarded", style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      if (canBoard && canCollectCash) const SizedBox(width: 10),
                      if (canCollectCash)
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _warning,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _collectCash(tripId, b.bookingId);
                              },
                              icon: const Icon(Icons.payments_rounded),
                              label: const Text("Collect Cash", style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markBoarded(int tripId, int bookingId) async {
    try {
      setState(() => _loading = true);
      await ConductorApi.board(bookingId: bookingId, tripId: tripId, source: "MANUAL");
      await _reloadBookings();
    } catch (e) {
      _toast("Board failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _collectCash(int tripId, int bookingId) async {
    try {
      setState(() => _loading = true);
      // offline safe idempotency
      final clientActionId = DateTime.now().microsecondsSinceEpoch.toString();
      await ConductorApi.payCash(
        bookingId: bookingId,
        tripId: tripId,
        clientActionId: clientActionId,
      );
      await _reloadBookings();
    } catch (e) {
      _toast("Payment failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _showTripEndedDialog(String type) async {
    final isCancelled = type == "TRIP_CANCELLED";
    final title = isCancelled ? "Trip cancelled" : "Trip ended";
    final message = "This trip is no longer active.";

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(isCancelled ? Icons.cancel_rounded : Icons.flag_rounded, color: _danger),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: _text2)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // ✅ stays
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context); // close dialog
                // ✅ manual exit only
                Navigator.popUntil(context, (r) => r.isFirst);
                Navigator.pushReplacementNamed(context, AppRoutes.conductorHome);
              },
              child: const Text("Close Trip", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
  }

  // ----------------- small UI helpers -----------------

  Widget _connPill({required bool connected}) {
    final c = connected ? _success : _warning;
    final label = connected ? "Online" : "Offline";
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }

  static Widget _statusPill({required String label, required Color color}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  static Widget _thinLoader() {
    return Container(
      height: 4,
      decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(999)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.38,
          child: Container(
            decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(999)),
          ),
        ),
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
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: _danger, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _info.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: _info, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: _text2, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(k, style: const TextStyle(color: _muted, fontWeight: FontWeight.w900, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  static String _hm(String hhmmss) {
    final s = hhmmss.toString();
    if (s.length >= 5) return s.substring(0, 5);
    return s;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1300)),
    );
  }
}

enum _Filter { all, notBoarded, boarded, cashPending, paid }
