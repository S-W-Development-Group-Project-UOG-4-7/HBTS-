import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../services/conductor_api.dart';
import '../state/conductor_store.dart';

class ConductorScanPage extends StatefulWidget {
  const ConductorScanPage({super.key});

  @override
  State<ConductorScanPage> createState() => _ConductorScanPageState();
}

class _ConductorScanPageState extends State<ConductorScanPage> {
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

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _busy = false; // prevents multiple verify calls
  String? _lastQr; // simple dedupe on our side too

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQr(String qr) async {
    if (_busy) return;

    final clean = qr.trim();
    if (clean.isEmpty) return;

    // basic dedupe (scan jitter)
    if (_lastQr == clean) return;
    _lastQr = clean;

    final store = context.read<ConductorStore>();
    final activeTripId = store.activeTrip?.tripId;

    setState(() => _busy = true);

    // pause scanning while verifying
    await _controller.stop();

    try {
      final res = await ConductorApi.scanVerify(
        qr: clean,
        tripId: activeTripId, // optional but recommended
      );

      final valid = (res["valid"] == true);

      if (!mounted) return;

      if (!valid) {
        final reason = (res["reason"] ?? "Invalid QR").toString();
        await _showInvalidSheet(reason);
        return;
      }

      // expected format from your backend:
      // { valid:true, booking:{...}, flags:{...} }
      final booking = (res["booking"] as Map?)?.cast<String, dynamic>() ?? {};
      final flags = (res["flags"] as Map?)?.cast<String, dynamic>() ?? {};

      await _showValidSheet(
        qr: clean,
        booking: booking,
        flags: flags,
        activeTripId: activeTripId,
      );
    } catch (e) {
      if (!mounted) return;
      await _showInvalidSheet(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);

      // resume scanner
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        await _controller.start();
      }
    }
  }

  Future<void> _showInvalidSheet(String reason) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
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
                _grab(),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Icon(Icons.cancel_rounded, color: _danger, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "Invalid",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    reason,
                    style: const TextStyle(color: _text2, fontWeight: FontWeight.w700),
                  ),
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
                    child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showValidSheet({
    required String qr,
    required Map<String, dynamic> booking,
    required Map<String, dynamic> flags,
    required int? activeTripId,
  }) async {
    final seat = (booking["seat_number"] ?? "").toString();
    final from = (booking["boarding_stop_name"] ?? "").toString();
    final to = (booking["dropping_stop_name"] ?? "").toString();
    final price = (booking["price"] ?? "").toString();

    final passengerName = (booking["passenger_name"] ?? "").toString();
    final passengerPhone = (booking["passenger_phone"] ?? "").toString();

    final alreadyBoarded = flags["alreadyBoarded"] == true;
    final alreadyPaid = flags["alreadyPaid"] == true;
    final cashPending = flags["cashPending"] == true;
    final canCollectCash = flags["canCollectCash"] == true; // from your verify response
    final canBoard = flags["canBoard"] == true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
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
                _grab(),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: _success, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      "Valid",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
                    ),
                    const Spacer(),
                    _pill(
                      label: alreadyPaid ? "PAID" : (cashPending ? "CASH PENDING" : "PENDING"),
                      color: alreadyPaid ? _success : _warning,
                    ),
                    const SizedBox(width: 8),
                    _pill(
                      label: alreadyBoarded ? "BOARDED" : "NOT BOARDED",
                      color: alreadyBoarded ? _success : _danger,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _kv("Seat", seat),
                if (passengerName.isNotEmpty) _kv("Passenger", passengerName),
                if (passengerPhone.isNotEmpty) _kv("Phone", passengerPhone),
                _kv("Stops", "$from → $to"),
                _kv("Price", "LKR $price"),

                const SizedBox(height: 14),

                // Actions
                if (!canBoard && !canCollectCash)
                  _infoBanner("Already completed (paid/boarded).")
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
                                await _commit(qr: qr, tripId: activeTripId, collectCash: false);
                              },
                              icon: const Icon(Icons.how_to_reg_rounded),
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
                                await _commit(qr: qr, tripId: activeTripId, collectCash: true);
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

  Future<void> _commit({
    required String qr,
    required int? tripId,
    required bool collectCash,
  }) async {
    try {
      // offline-safe idempotency
      final clientActionId = DateTime.now().microsecondsSinceEpoch.toString();

      final res = await ConductorApi.scanCommit(
        qr: qr,
        tripId: tripId,
        source: "QR",
        collectCash: collectCash,
        clientActionId: clientActionId,
      );

      // If backend returns 409 for cash pending and collectCash=false,
      // user should press Collect Cash button instead.
      if (!mounted) return;

      final ok = res["ok"] == true;
      if (ok) {
        _toast(collectCash ? "Cash collected + boarded" : "Boarded");
        // refresh active trip + bookings views when user goes back
        await context.read<ConductorStore>().refreshActiveTrip();
      } else {
        _toast(res["message"]?.toString() ?? "Action failed");
      }
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConductorStore>();
    final connected = store.wsConnected;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Scan QR", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: "Toggle torch",
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _connDot(connected),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final codes = capture.barcodes;
              if (codes.isEmpty) return;
              final raw = codes.first.rawValue;
              if (raw == null) return;
              _handleQr(raw);
            },
          ),

          // overlay (wireframe style)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // scan frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 2),
              ),
            ),
          ),

          // bottom instruction
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: _card(
              padding: 14,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _info.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _info.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: _info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _busy
                          ? "Verifying..."
                          : "Align the QR code inside the frame to verify the booking.",
                      style: const TextStyle(color: _text2, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI helpers ----------
  static Widget _grab() => Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(999)),
      );

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
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  static Widget _infoBanner(String msg) {
    return Container(
      width: double.infinity,
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
            width: 92,
            child: Text(
              k,
              style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connDot(bool connected) {
    final c = connected ? _success : _warning;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1300)),
    );
  }
}
