import 'package:flutter/foundation.dart';
import '../models/conductor_active_trip_model.dart';
import '../models/conductor_booking_model.dart';
import '../services/conductor_api.dart';

enum BookingFilter { all, notBoarded, boarded, cashPending, paid }

class ActiveTripStore extends ChangeNotifier {
  bool loading = false;
  String? error;

  ConductorActiveTrip? trip;
  List<ConductorBooking> bookings = const [];

  BookingFilter filter = BookingFilter.all;

  bool tripClosedDialogRequested = false;
  String? tripClosedReason; // "ended" | "cancelled"

  int get boardedCount => bookings.where((b) => b.isBoarded).length;
  int get cashPendingCount => bookings.where((b) => b.isCashPending).length;
  int get paidCount => bookings.where((b) => b.isPaid).length;

  List<ConductorBooking> get filtered {
    switch (filter) {
      case BookingFilter.notBoarded:
        return bookings.where((b) => !b.isBoarded).toList();
      case BookingFilter.boarded:
        return bookings.where((b) => b.isBoarded).toList();
      case BookingFilter.cashPending:
        return bookings.where((b) => b.isCashPending).toList();
      case BookingFilter.paid:
        return bookings.where((b) => b.isPaid).toList();
      case BookingFilter.all:
      default:
        return bookings;
    }
  }

  void setFilter(BookingFilter f) {
    filter = f;
    notifyListeners();
  }

  Future<void> loadActiveTripAndBookings() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      trip = await ConductorApi.getMyActiveTrip();
      if (trip == null) {
        bookings = const [];
      } else {
        bookings = await ConductorApi.getTripBookings(tripId: trip!.tripId);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Call this from WS events (TRIP_ENDED/TRIP_CANCELLED)
  void requestTripClosedDialog({required String reason}) {
    tripClosedReason = reason;
    tripClosedDialogRequested = true;
    notifyListeners();
  }

  void clearTripClosedDialogRequest() {
    tripClosedDialogRequested = false;
    notifyListeners();
  }
}
