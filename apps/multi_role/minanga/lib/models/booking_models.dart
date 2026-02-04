import 'package:flutter/foundation.dart';

enum BookingStatus { scheduled, delayed, cancelled, onboard, completed }

@immutable
class Booking {
  final String bookingId;
  final String route;
  final DateTime dateTime;
  final BookingStatus status;

  /// Bus / trip metadata used for rules
  final String tripId;
  final String busId;

  /// Your selected seats (usually 1 seat, but keep list)
  final List<String> seats; // e.g. ["A1"]

  /// Seat layout key if multiple layouts exist
  final String layoutId;

  const Booking({
    required this.bookingId,
    required this.route,
    required this.dateTime,
    required this.status,
    required this.tripId,
    required this.busId,
    required this.seats,
    required this.layoutId,
  });

  bool get isEditable {
    // allow edits only before onboard/completed/cancelled
    return status == BookingStatus.scheduled || status == BookingStatus.delayed;
  }

  bool get isCancellable {
    return status == BookingStatus.scheduled || status == BookingStatus.delayed;
  }

  Booking copyWith({
    BookingStatus? status,
    List<String>? seats,
  }) {
    return Booking(
      bookingId: bookingId,
      route: route,
      dateTime: dateTime,
      status: status ?? this.status,
      tripId: tripId,
      busId: busId,
      seats: seats ?? this.seats,
      layoutId: layoutId,
    );
  }
}
