import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/conductor_bus_model.dart';
import '../models/conductor_active_trip_model.dart';
import '../models/conductor_trip_summary_model.dart';
import '../models/conductor_booking_model.dart';

import '../services/conductor_api.dart';
import '../services/realtime_ws.dart';

class ConductorStore extends ChangeNotifier {
  bool loading = false;
  String? error;

  ConductorBus? myBus;
  ConductorActiveTrip? activeTrip;

  // ✅ FIX: this must match ConductorApi.getMyTrips() return type
  List<ConductorTripSummary> todayTrips = const [];

  // -------------------------
  // Active trip bookings (Bookings tab)
  // -------------------------

  List<ConductorBooking> activeTripBookings = const [];
  List<ConductorBooking> tripBookings = const [];
  int? currentTripIdForBookings;

  String bookingSearch = "";

  /// allowed values should match what your UI uses
  /// "all", "not_boarded", "boarded"
  String bookingFilter = "all";

  void setBookingSearch(String q) {
    bookingSearch = q.trim();
    notifyListeners();
  }

  /// values: "all", "not_boarded", "boarded"
  void setBookingFilter(String value) {
    bookingFilter = value;
    notifyListeners();
  }

  Future<void> loadActiveTripBookings({int page = 1, int limit = 50}) async {
    final tripId = activeTrip?.tripId;
    if (tripId == null) {
      activeTripBookings = const [];
      notifyListeners();
      return;
    }

    try {
      // Map UI filter -> API query
      // If you later add status/payment filters to backend, extend ConductorApi.getTripBookings(...)
      activeTripBookings = await ConductorApi.getTripBookings(
        tripId: tripId,
        page: page,
        limit: limit,
      );

      // Apply simple client-side filters until backend filters are wired
      final q = bookingSearch.toLowerCase();
      final filtered = activeTripBookings.where((b) {
        final matchesSearch = q.isEmpty ||
            b.seatNumber.toLowerCase().contains(q) ||
            b.bookingId.toString().contains(q) ||
            b.passengerName.toLowerCase().contains(q) ||
            b.passengerPhone.toLowerCase().contains(q);

        final matchesStatus = q.isNotEmpty ||
            bookingFilter == "all" ||
            (bookingFilter == "boarded" && b.isBoarded) ||
            (bookingFilter == "not_boarded" && !b.isBoarded) ||
            (bookingFilter == "cash_pending" && b.isCashPending) ||
            (bookingFilter == "paid" && b.isPaid);

        return matchesSearch && matchesStatus;
      }).toList();

      activeTripBookings = filtered;
      notifyListeners();
    } catch (e) {
      // don’t crash UI
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadTripBookings(int tripId, {int page = 1, int limit = 50}) async {
    currentTripIdForBookings = tripId;
    notifyListeners();

    if (tripId <= 0) {
      tripBookings = const [];
      notifyListeners();
      return;
    }

    try {
      final list = await ConductorApi.getTripBookings(
        tripId: tripId,
        page: page,
        limit: limit,
      );

      final q = bookingSearch.toLowerCase();
      final filtered = list.where((b) {
        final matchesSearch = q.isEmpty ||
            b.seatNumber.toLowerCase().contains(q) ||
            b.bookingId.toString().contains(q) ||
            b.passengerName.toLowerCase().contains(q) ||
            b.passengerPhone.toLowerCase().contains(q);

        final matchesStatus = q.isNotEmpty ||
            bookingFilter == "all" ||
            (bookingFilter == "boarded" && b.isBoarded) ||
            (bookingFilter == "not_boarded" && !b.isBoarded) ||
            (bookingFilter == "cash_pending" && b.isCashPending) ||
            (bookingFilter == "paid" && b.isPaid);

        return matchesSearch && matchesStatus;
      }).toList();

      tripBookings = filtered;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  // -------------------------
  // Realtime WS
  // -------------------------
  final RealtimeWsService _realtime = RealtimeWsService();
  StreamSubscription? _evSub;
  StreamSubscription? _stSub;

  RealtimeConnStatus _wsStatus = RealtimeConnStatus.disconnected;

  /// ✅ Used by UI for the green/orange dot
  bool get wsConnected => _wsStatus == RealtimeConnStatus.connected;

  /// Optional: if you want to show "Connecting..." somewhere
  RealtimeConnStatus get wsStatus => _wsStatus;

  /// ✅ UI can listen to this to show Trip End/Cancel modal (NO auto nav)
  final StreamController<RealtimeEvent> _tripEvents = StreamController.broadcast();
  Stream<RealtimeEvent> get tripEvents => _tripEvents.stream;

  // Call this once after login / when conductor app starts
  void startRealtime() {
    // Avoid double-wiring
    _stSub ??= _realtime.status.listen((s) {
      _wsStatus = s;
      notifyListeners();
    });

    _evSub ??= _realtime.events.listen((ev) async {
      // Forward trip lifecycle events to UI
      if (ev.isTripStarted || ev.isTripEnded || ev.isTripCancelled) {
        if (!_tripEvents.isClosed) _tripEvents.add(ev);

        // Backend is source of truth: refresh active trip on any trip event
        await refreshActiveTrip();
      }
    });

    _realtime.connect();
  }

  Future<void> stopRealtime() async {
    await _realtime.disconnect();
  }

  // -------------------------
  // Data loading
  // -------------------------
  Future<void> initHome({required String todayYYYYMMDD}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      myBus = await ConductorApi.getMyBus();
      activeTrip = await ConductorApi.getMyActiveTrip();
      todayTrips = await ConductorApi.getMyTrips(dateYYYYMMDD: todayYYYYMMDD);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshActiveTrip() async {
    try {
      activeTrip = await ConductorApi.getMyActiveTrip();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _evSub?.cancel();
    _stSub?.cancel();
    _tripEvents.close();
    _realtime.dispose();
    super.dispose();
  }
}
