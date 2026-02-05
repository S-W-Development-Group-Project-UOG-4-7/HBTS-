class ConductorTripSummary {
  final int tripId;
  final int routeId;
  final int operatorId;
  final int busId;
  final int driverId;
  final String tripDate;
  final String departureTime;
  final String arrivalTime;
  final String status;

  final String routeName;
  final String startLocation; // from_location
  final String endLocation;   // to_location

  ConductorTripSummary({
    required this.tripId,
    required this.routeId,
    required this.operatorId,
    required this.busId,
    required this.driverId,
    required this.tripDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.routeName,
    required this.startLocation,
    required this.endLocation,
  });

  factory ConductorTripSummary.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.parse(v.toString());
    }

    return ConductorTripSummary(
      tripId: toInt(j["trip_id"]),
      routeId: toInt(j["route_id"]),
      operatorId: toInt(j["operator_id"]),
      busId: toInt(j["bus_id"]),
      driverId: toInt(j["driver_id"]),
      tripDate: j["trip_date"].toString(),
      departureTime: j["departure_time"].toString(),
      arrivalTime: j["arrival_time"].toString(),
      status: j["status"].toString(),
      routeName: j["route_name"].toString(),
      startLocation: j["from_location"].toString(),
      endLocation: j["to_location"].toString(),
    );
  }

  bool get isRunning => status.toLowerCase() == "running" || status.toLowerCase() == "ongoing";
}
