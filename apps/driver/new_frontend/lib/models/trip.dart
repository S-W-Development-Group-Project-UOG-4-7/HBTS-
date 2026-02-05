import 'package:flutter/material.dart';

class Trip {
  final int tripId;
  final int routeId;
  final String routeName;
  final String fromLocation;
  final String toLocation;
  final DateTime tripDate;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String status;
  final int? driverId;
  final int? busId;

  Trip({
    required this.tripId,
    required this.routeId,
    required this.routeName,
    required this.fromLocation,
    required this.toLocation,
    required this.tripDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    this.driverId,
    this.busId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['trip_id'],
      routeId: json['route_id'],
      routeName: json['route_name'] ?? '',
      fromLocation: json['from_location'] ?? '',
      toLocation: json['to_location'] ?? '',
      tripDate: DateTime.parse(json['trip_date']),
      departureTime: DateTime.parse(json['departure_time']),
      arrivalTime: DateTime.parse(json['arrival_time']),
      status: (json['status'] ?? 'scheduled').toString().toLowerCase(),
      driverId: json['driver_id'],
      busId: json['bus_id'],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'running':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'scheduled':
        return const Color(0xFF2196F3); // Blue
      case 'running':
        return const Color(0xFF4CAF50); // Green
      case 'completed':
        return const Color(0xFF9E9E9E); // Grey
      case 'cancelled':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF757575);
    }
  }
}
