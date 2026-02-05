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
  final int boardingStopId;
  final String boardingStopName;
  final double? boardingStopLat;
  final double? boardingStopLon;

  final DateTime tripDate;
  final DateTime departureTime;
  final DateTime arrivalTime;

  final DateTime bookingTime;
  final String? qrCode;

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
    required this.boardingStopId,
    required this.boardingStopName,
    this.boardingStopLat,
    this.boardingStopLon,
    required this.tripDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.bookingTime,
    this.qrCode,
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
      boardingStopId: _asInt(j["boarding_stop_id"]),
      boardingStopName: (j["boarding_stop_name"] ?? "").toString(),
      boardingStopLat: _asDoubleOrNull(j["boarding_stop_lat"]),
      boardingStopLon: _asDoubleOrNull(j["boarding_stop_lon"]),
      tripDate: DateTime.parse(j["trip_date"] as String),
      departureTime: DateTime.parse(j["departure_time"] as String),
      arrivalTime: DateTime.parse(j["arrival_time"] as String),
      bookingTime: DateTime.parse(j["booking_time"] as String),
      qrCode: (j["qr_code"] as String?),
    );
  }

  String get routeText => routeName.isNotEmpty ? routeName : "$fromLocation → $toLocation";

  bool get isHistory {
    final t = tripStatus.toLowerCase().trim();
    final s = status.toLowerCase().trim();
    final now = DateTime.now();

    // Always history if backend says so
    if (t == "cancelled" || t == "completed") return true;
    if (s == "cancelled" || s == "expired") return true;

    // scheduled/running/started => move to history 24h after arrival time
    if (now.isAfter(arrivalTime.add(const Duration(hours: 24)))) {
      return true;
    }

    return false;
  }
}

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? "") ?? 0;
}

double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
