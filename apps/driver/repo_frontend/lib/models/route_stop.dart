class RouteStop {
  final int stopId;
  final String stopName;
  final double lat;
  final double lon;
  final int sequence;
  final String? arrivalTime;
  final String? departureTime;

  RouteStop({
    required this.stopId,
    required this.stopName,
    required this.lat,
    required this.lon,
    required this.sequence,
    this.arrivalTime,
    this.departureTime,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopId: json['stop_id'],
      stopName: json['stop_name'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      sequence: json['sequence'] ?? 0,
      arrivalTime: json['arrival_time'],
      departureTime: json['departure_time'],
    );
  }
}
