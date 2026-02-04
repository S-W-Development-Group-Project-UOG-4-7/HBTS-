import 'json_parse.dart';

class ConductorActiveTrip {
  final int tripId;
  final int routeId;
  final int operatorId;
  final int busId;
  final int driverId;

  final String tripDate; // "YYYY-MM-DD"
  final String departureTime; // "HH:mm:ss"
  final String arrivalTime; // "HH:mm:ss"

  final String status; // "ongoing"
  final String routeName;
  final String startLocation;
  final String endLocation;

  ConductorActiveTrip({
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

  factory ConductorActiveTrip.fromJson(Map<String, dynamic> j) {
    return ConductorActiveTrip(
      tripId: jInt(j["trip_id"]),
      routeId: jInt(j["route_id"]),
      operatorId: jInt(j["operator_id"]),
      busId: jInt(j["bus_id"]),
      driverId: jInt(j["driver_id"]),
      tripDate: jStr(j["trip_date"]),
      departureTime: jStr(j["departure_time"]),
      arrivalTime: jStr(j["arrival_time"]),
      status: jStr(j["status"]),
      routeName: jStr(j["route_name"]),
      startLocation: jStr(j["from_location"]),
      endLocation: jStr(j["to_location"]),
    );
  }

  bool get isRunning => status.toLowerCase() == "ongoing" || status.toLowerCase() == "running";
}
