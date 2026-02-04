import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../models/booking.dart';
import '../models/route_stop.dart';

class ApiService extends ChangeNotifier {
  // Change this to your backend URL
  // For Android Emulator use: http://10.0.2.2:3000
  // For Web/Desktop/iOS Simulator use: http://localhost:3000
  // For real device use: your computer's IP
  static const String baseUrl =
      kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';

  int? _driverId;
  bool _isLoading = false;

  int? get driverId => _driverId;
  bool get isLoading => _isLoading;

  void setDriverId(int id) {
    _driverId = id;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Get driver's assigned trips
  Future<List<Trip>> getDriverTrips(int driverId) async {
    try {
      setLoading(true);
      final response = await http.get(
        Uri.parse('$baseUrl/driver/$driverId/trips'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Trip.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load trips');
      }
    } catch (e) {
      print('Error fetching trips: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Start a trip
  Future<bool> startTrip(int tripId) async {
    try {
      setLoading(true);
      final response = await http.put(
        Uri.parse('$baseUrl/driver/trip/$tripId/start'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error starting trip: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // End a trip
  Future<bool> endTrip(int tripId) async {
    try {
      setLoading(true);
      final response = await http.put(
        Uri.parse('$baseUrl/driver/trip/$tripId/end'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error ending trip: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Get route details with stops
  Future<List<RouteStop>> getRouteStops(int tripId) async {
    try {
      setLoading(true);
      final response = await http.get(
        Uri.parse('$baseUrl/driver/trip/$tripId/route'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RouteStop.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load route');
      }
    } catch (e) {
      print('Error fetching route: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Get booked seats for a trip
  Future<List<Booking>> getTripBookings(int tripId) async {
    try {
      setLoading(true);
      final response = await http.get(
        Uri.parse('$baseUrl/driver/trip/$tripId/bookings'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Booking.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load bookings');
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Send telemetry data
  Future<bool> sendTelemetry({
    required int tripId,
    required int busId,
    required double lat,
    required double lon,
    double? speed,
    int? heading,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/trip/$tripId/telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'bus_id': busId,
          'trip_id': tripId,
          'lat': lat,
          'lon': lon,
          'speed': speed,
          'heading': heading,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error sending telemetry: $e');
      return false;
    }
  }
}
