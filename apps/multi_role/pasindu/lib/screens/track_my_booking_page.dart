import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../services/booking_api.dart';
import '../services/tracking_socket_service.dart';
import '../config.dart';
import '../services/token_store.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackMyBookingPage extends StatefulWidget {
  final int? bookingId;

  const TrackMyBookingPage({Key? key, this.bookingId}) : super(key: key);

  @override
  State<TrackMyBookingPage> createState() => _TrackMyBookingPageState();
}

class _TrackMyBookingPageState extends State<TrackMyBookingPage> {
  final TrackingSocketService _socket = TrackingSocketService();
  StreamSubscription? _sub;

  bool _loading = true;
  String? _error;

  int? _tripId;

  // Live data
  int? _etaMinutes;
  DateTime? _lastGpsAt;

  Map<String, dynamic>? _snapshot;
  String? _tripStatus;

  // Google Map state
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _boardingLatLng;
  LatLng? _droppingLatLng;
  LatLng? _busLatLng;

  String _boardingName = "Boarding";
  String _droppingName = "Dropping";

  bool _autoFollowBus = true;
  bool _didFitOnce = false;

  Timer? _busAnimTimer;
  LatLng? _busAnimFrom;
  LatLng? _busAnimTo;
  double _busAnimT = 0.0;
  static const int _busAnimMs = 900;
  static const int _busAnimTickMs = 45;
  bool _nearAlertShown = false;
  static const double _nearMeters = 1000;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ---------- helpers ----------
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime? _parseDbTs(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final fixed = s.endsWith('Z') ? s : '${s}Z';
    return DateTime.tryParse(fixed);
  }

  String? _normalizeStatus(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim().toLowerCase();
    return s.isEmpty ? null : s;
  }

  bool get _tripStarted {
    final s = _tripStatus;
    if (s == null) return true;
    return s == "running" || s == "started";
  }

  bool get _tripNotStarted {
    final s = _tripStatus;
    if (s == null) return false;
    return s == "scheduled" || s == "pending" || s == "created";
  }

  bool get _isStale {
    if (_lastGpsAt == null) return false;
    return DateTime.now().difference(_lastGpsAt!).inSeconds > 45;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);

    return 2 * R * math.asin(math.sqrt(h));
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    final lat = a.latitude + (b.latitude - a.latitude) * t;
    final lng = a.longitude + (b.longitude - a.longitude) * t;
    return LatLng(lat, lng);
  }

  void _animateBusTo(LatLng target) {
    if (_busLatLng == null) {
      setState(() => _busLatLng = target);
      _rebuildMarkers();
      return;
    }

    _busAnimTimer?.cancel();
    _busAnimFrom = _busLatLng;
    _busAnimTo = target;
    _busAnimT = 0.0;

    final steps = (_busAnimMs / _busAnimTickMs).round().clamp(1, 60);
    final dt = 1.0 / steps;

    _busAnimTimer = Timer.periodic(const Duration(milliseconds: _busAnimTickMs), (timer) {
      _busAnimT += dt;
      final t = _busAnimT.clamp(0.0, 1.0);

      final next = _lerpLatLng(_busAnimFrom!, _busAnimTo!, t);

      setState(() => _busLatLng = next);
      _rebuildMarkers();

      if (_autoFollowBus && _mapCtrl != null) {
        _mapCtrl!.animateCamera(CameraUpdate.newLatLng(next));
      }

      if (t >= 1.0) timer.cancel();
    });
  }

  Future<String?> _fetchTripPolyline(int tripId) async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse("${AppConfig.baseUrl}/api/trips/$tripId");
    final res = await http.get(uri, headers: {"Authorization": "Bearer $token"});

    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final poly = data["polyline"];
    if (poly == null) return null;
    return poly.toString();
  }

  void _setRoutePolyline(String encoded) {
    final points = PolylinePoints().decodePolyline(encoded);
    if (points.isEmpty) return;

    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: latLngs,
            width: 5,
          ),
        );
    });
  }

  void _rebuildMarkers() {
    if (!mounted) return;

    final markers = <Marker>{};

    if (_boardingLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('boarding'),
        position: _boardingLatLng!,
        infoWindow: InfoWindow(title: "Boarding: $_boardingName"),
      ));
    }

    if (_droppingLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropping'),
        position: _droppingLatLng!,
        infoWindow: InfoWindow(title: "Dropping: $_droppingName"),
      ));
    }

    if (_busLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('bus'),
        position: _busLatLng!,
        infoWindow: const InfoWindow(title: "Bus"),
      ));
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  void _fitToAll() {
    if (_mapCtrl == null) return;

    final points = <LatLng>[];
    if (_boardingLatLng != null) points.add(_boardingLatLng!);
    if (_droppingLatLng != null) points.add(_droppingLatLng!);
    if (_busLatLng != null) points.add(_busLatLng!);

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 13));
      return;
    }

    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  // ---------- init ----------
  Future<void> _init() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      _nearAlertShown = false;

      if (widget.bookingId == null) {
        throw Exception("Missing bookingId. Please open this screen from a specific booking.");
      }

      // 1) Snapshot
      final snap = await BookingApi.getBookingTracking(widget.bookingId!);

      final tripId = (snap['trip_id'] as num).toInt();
      _tripId = tripId;
      _snapshot = snap;
      _tripStatus = _normalizeStatus(
        snap['trip_status'] ?? snap['tripStatus'] ?? snap['trip_state'] ?? snap['status'],
      );

      _boardingName = (snap['boarding_stop_name'] ?? "Boarding").toString();
      _droppingName = (snap['dropping_stop_name'] ?? "Dropping").toString();

      final blat = _toDouble(snap['boarding_lat']);
      final blon = _toDouble(snap['boarding_lon']);
      if (blat != null && blon != null) _boardingLatLng = LatLng(blat, blon);

      final dlat = _toDouble(snap['dropping_lat']);
      final dlon = _toDouble(snap['dropping_lon']);
      if (dlat != null && dlon != null) _droppingLatLng = LatLng(dlat, dlon);

      final busLat = _toDouble(snap['bus_lat']);
      final busLon = _toDouble(snap['bus_lon']);
      if (busLat != null && busLon != null) _busLatLng = LatLng(busLat, busLon);

      _lastGpsAt = _parseDbTs(snap['bus_gps_at']);

      _rebuildMarkers();

      // 1b) Route polyline
      final encoded = await _fetchTripPolyline(tripId);
      if (encoded != null && encoded.isNotEmpty) {
        _setRoutePolyline(encoded);
      }

      if (_tripNotStarted) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_didFitOnce) {
            _didFitOnce = true;
            _fitToAll();
          }
        });
        return;
      }

      // 2) WebSocket connect + subscribe
      await _socket.connect();
      _socket.subscribe(tripId: tripId, bookingId: widget.bookingId!);

      // 3) Listen for live updates (NO refresh needed)
      await _sub?.cancel();
      _sub = _socket.stream().listen((msg) {
        if (!mounted) return;

        final type = msg['type'];

        if (type == 'tracking_update') {
          final loc = (msg['location'] as Map).cast<String, dynamic>();
          final eta = (msg['eta'] as Map).cast<String, dynamic>();

          final lat = _toDouble(loc['lat']);
          final lon = _toDouble(loc['lon']);
          if (lat == null || lon == null) return;

          final nextPos = LatLng(lat, lon);

          setState(() {
            _etaMinutes = (eta['etaMinutes'] as num).toInt();
            _lastGpsAt = _parseDbTs(loc['gps_at']) ?? _lastGpsAt;
          });

          _animateBusTo(nextPos);

          if (!_nearAlertShown && _boardingLatLng != null) {
            final d = _haversineMeters(nextPos, _boardingLatLng!);
            if (d <= _nearMeters) {
              _nearAlertShown = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Bus is near your boarding stop (${d.toStringAsFixed(0)}m)"),
                ),
              );
            }
          }

          if (!_didFitOnce && _mapCtrl != null) {
            _didFitOnce = true;
            _fitToAll();
          }

          if (_autoFollowBus && _mapCtrl != null && _busLatLng != null) {
            _mapCtrl!.animateCamera(CameraUpdate.newLatLng(_busLatLng!));
          }
        }

        if (type == 'boarding_passed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bus has passed your boarding stop"),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      setState(() => _loading = false);

      // Fit once after UI shown
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_didFitOnce) {
          _didFitOnce = true;
          _fitToAll();
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _busAnimTimer?.cancel();
    _busAnimTimer = null;
    if (_tripId != null) _socket.unsubscribe(tripId: _tripId!);
    _socket.close();

    _mapCtrl?.dispose();
    super.dispose();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;

    final initial = _busLatLng ?? _boardingLatLng ?? const LatLng(6.9271, 79.8612);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track My Booking"),
        actions: [
          IconButton(
            tooltip: "Fit",
            onPressed: _fitToAll,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: widget.bookingId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Missing bookingId. Please open this screen from a specific booking.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Back"),
                    ),
                  ],
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (_tripNotStarted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.schedule, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Trip has not started yet. You still have time.",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (!_tripNotStarted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.directions_bus, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Bus has started the trip and is on the way.",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_tripStarted && _isStale)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.gps_off, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "GPS update is stale. Waiting for new location...",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Booking ID: ${widget.bookingId}   ?   Trip ID: ${_tripId ?? '-'}",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.login, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Boarding: ${snap?['boarding_stop_name'] ?? '-'}",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.logout, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Dropping: ${snap?['dropping_stop_name'] ?? '-'}",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isStale
                                      ? "ETA: calculating..."
                                      : "ETA: ${_etaMinutes != null ? '$_etaMinutes min' : '?'}",
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  "GPS: ${_lastGpsAt?.toLocal().toString().split('.').first ?? '?'}",
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(target: initial, zoom: 12.5),
                            markers: _markers,
                            polylines: _polylines,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onMapCreated: (c) {
                              _mapCtrl = c;
                              _fitToAll();
                            },
                            onCameraMoveStarted: () {
                              if (_autoFollowBus) setState(() => _autoFollowBus = false);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Auto-follow bus"),
                              value: _autoFollowBus,
                              onChanged: (v) => setState(() => _autoFollowBus = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _fitToAll,
                            icon: const Icon(Icons.fit_screen),
                            label: const Text("Fit"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
