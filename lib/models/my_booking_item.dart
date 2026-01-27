class MyBookingItem {
  final int bookingId;
  final int tripId;
  final int seatId;

  final String status;      // pending | confirmed
  final String tripStatus;  // scheduled | cancelled | completed | ...

  final String routeName;
  final String fromLocation;
  final String toLocation;
  final String seatLabel;

  final DateTime tripDate;
  final DateTime departureTime;
  final DateTime arrivalTime;

  final DateTime bookingTime;

  MyBookingItem({
    required this.bookingId,
    required this.tripId,
    required this.seatId,
    required this.status,
    required this.tripStatus,
    required this.routeName,
    required this.fromLocation,
    required this.toLocation,
    required this.seatLabel,
    required this.tripDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.bookingTime,
  });

  factory MyBookingItem.fromJson(Map<String, dynamic> j) {
    return MyBookingItem(
      bookingId: (j["booking_id"] as num).toInt(),
      tripId: (j["trip_id"] as num).toInt(),
      seatId: (j["seat_id"] as num).toInt(),
      status: (j["status"] ?? "") as String,
      tripStatus: (j["trip_status"] ?? "") as String,
      routeName: (j["route_name"] ?? "") as String,
      fromLocation: (j["from_location"] ?? "") as String,
      toLocation: (j["to_location"] ?? "") as String,
      seatLabel: (j["seat_label"] ?? "") as String,
      tripDate: DateTime.parse(j["trip_date"] as String),
      departureTime: DateTime.parse(j["departure_time"] as String),
      arrivalTime: DateTime.parse(j["arrival_time"] as String),
      bookingTime: DateTime.parse(j["booking_time"] as String),
    );
  }

  String get routeText => routeName.isNotEmpty ? routeName : "$fromLocation → $toLocation";

  bool get isHistory {
    final t = tripStatus.toLowerCase();
    return t == "cancelled" || t == "completed";
  }
}
