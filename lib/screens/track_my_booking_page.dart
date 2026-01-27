import 'package:flutter/material.dart';
import 'dart:async';


import '../services/booking_api.dart';
import '../services/tracking_socket_service.dart';

class TrackMyBookingPage extends StatefulWidget {
  final int? bookingId;

  const TrackMyBookingPage({
    Key? key,
    this.bookingId,
  }) : super(key: key);

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
  double? _busLat;
  double? _busLon;
  int? _etaMinutes;
  DateTime? _lastGpsAt;

  Map<String, dynamic>? _snapshot;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      if (widget.bookingId == null) {
        throw Exception("Missing bookingId. Please open this screen from a specific booking.");
      }

      // 1) Snapshot (gives trip_id + last bus location if exists)
      final snap = await BookingApi.getBookingTracking(widget.bookingId!);

      final tripId = (snap['trip_id'] as num).toInt();
      _tripId = tripId;
      _snapshot = snap;

      // If backend already has a last bus location, show it
      if (snap['bus_lat'] != null && snap['bus_lon'] != null) {
        _busLat = (snap['bus_lat'] as num).toDouble();
        _busLon = (snap['bus_lon'] as num).toDouble();
      }
      if (snap['bus_gps_at'] != null) {
        _lastGpsAt = DateTime.tryParse(snap['bus_gps_at'].toString());
      }

      // 2) WebSocket connect + subscribe
      await _socket.connect();
      _socket.subscribe(tripId: tripId, bookingId: widget.bookingId!);

      // 3) Listen for live updates (cancel previous first)
      await _sub?.cancel();
      _sub = _socket.stream().listen((msg) {
        final type = msg['type'];
        if (type == 'tracking_update') {
          final loc = (msg['location'] as Map).cast<String, dynamic>();
          final eta = (msg['eta'] as Map).cast<String, dynamic>();

          setState(() {
            _busLat = (loc['lat'] as num).toDouble();
            _busLon = (loc['lon'] as num).toDouble();
            _etaMinutes = (eta['etaMinutes'] as num).toInt();

            final gpsAtStr = loc['gps_at']?.toString();
            _lastGpsAt = gpsAtStr != null ? DateTime.tryParse(gpsAtStr) : _lastGpsAt;
          });
        } else if (type == 'location_update') {
          // fallback event (if ever sent)
          final loc = (msg['location'] as Map).cast<String, dynamic>();
          setState(() {
            _busLat = (loc['lat'] as num).toDouble();
            _busLon = (loc['lon'] as num).toDouble();
            final gpsAtStr = loc['gps_at']?.toString();
            _lastGpsAt = gpsAtStr != null ? DateTime.tryParse(gpsAtStr) : _lastGpsAt;
          });
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _isStale {
    if (_lastGpsAt == null) return false;
    final diff = DateTime.now().difference(_lastGpsAt!);
    return diff.inSeconds > 45;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    // optional unsubscribe before closing
    if (_tripId != null) {
      _socket.unsubscribe(tripId: _tripId!);
    }
    _socket.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text("Track My Booking")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      if (_isStale)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "GPS update is stale. Waiting for new location...",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (_isStale) const SizedBox(height: 12),

                      Text("Booking ID: ${widget.bookingId}"),
                      Text("Trip ID: ${_tripId ?? '-'}"),
                      const SizedBox(height: 12),

                      if (snap != null) ...[
                        Text("Boarding stop: ${snap['boarding_stop_name'] ?? '-'}"),
                        Text("Dropping stop: ${snap['dropping_stop_name'] ?? '-'}"),
                        const SizedBox(height: 12),
                      ],

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Live Bus Location",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text("Lat: ${_busLat?.toStringAsFixed(6) ?? '—'}"),
                              Text("Lon: ${_busLon?.toStringAsFixed(6) ?? '—'}"),
                              const SizedBox(height: 8),
                              Text("ETA to boarding stop: ${_etaMinutes != null ? '$_etaMinutes min' : '—'}"),
                              const SizedBox(height: 8),
                              Text("Last GPS: ${_lastGpsAt?.toLocal().toString() ?? '—'}"),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _init,
                        child: const Text("Refresh"),
                      ),
                    ],
                  ),
                ),
    );
  }
}
