class Trip {
  final int id;
  final String routeName;
  final String fromLocation;
  final String toLocation;
  final DateTime tripDate;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String status;
  final int capacity;
  final String serviceType;

  Trip({
    required this.id,
    required this.routeName,
    required this.fromLocation,
    required this.toLocation,
    required this.tripDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.capacity,
    required this.serviceType,
  });

  factory Trip.fromJson(Map<String, dynamic> j) {
    return Trip(
      id: (j["id"] as num).toInt(),
      routeName: (j["route_name"] ?? "") as String,
      fromLocation: (j["from_location"] ?? "") as String,
      toLocation: (j["to_location"] ?? "") as String,
      tripDate: DateTime.parse(j["trip_date"]),
      departureTime: DateTime.parse(j["departure_time"]),
      arrivalTime: DateTime.parse(j["arrival_time"]),
      status: (j["status"] ?? "") as String,
      capacity: (j["capacity"] as num).toInt(),
      serviceType: (j["service_type"] ?? "") as String,
    );
  }
}
