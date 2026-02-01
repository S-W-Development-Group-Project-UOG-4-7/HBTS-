import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/token_store.dart';
import '../models/my_booking_item.dart';

class BookingApi {
  static Future<int> createBooking({
    required int tripId,
    required int seatId,
    required int boardingStopId,
    required int droppingStopId,
    required String paidVia, // "cash" | "online"
  }) async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception("Not logged in (missing access token)");
    }

    final uri = Uri.parse("${AppConfig.baseUrl}/api/bookings");
    final res = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "tripId": tripId,
        "seatId": seatId,
        "boardingStopId": boardingStopId,
        "droppingStopId": droppingStopId,
        "paidVia": paidVia,
      }),
    );

    if (res.statusCode != 201) {
      throw Exception("Booking failed (${res.statusCode}): ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data["bookingId"] as num).toInt();
  }

  static Future<List<MyBookingItem>> getMyBookings() async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception("Not logged in (missing access token)");
    }

    final uri = Uri.parse("${AppConfig.baseUrl}/api/bookings/me");
    final res = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("My bookings fetch failed (${res.statusCode}): ${res.body}");
    }

    final List data = jsonDecode(res.body) as List;
    return data
        .map((e) => MyBookingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> getBookingTracking(int bookingId) async {
  final token = await TokenStore.getAccessToken();
  if (token == null || token.isEmpty) {
    throw Exception("Not logged in (missing access token)");
  }

  final uri = Uri.parse("${AppConfig.baseUrl}/api/bookings/$bookingId/tracking");
  final res = await http.get(
    uri,
    headers: {"Authorization": "Bearer $token"},
  );

  if (res.statusCode != 200) {
    throw Exception("Tracking snapshot failed (${res.statusCode}): ${res.body}");
  }

  return jsonDecode(res.body) as Map<String, dynamic>;
}


  static Future<void> changeSeat({
    required int bookingId,
    required int seatId,
  }) async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception("Not logged in (missing access token)");
    }

    final uri = Uri.parse("${AppConfig.baseUrl}/api/bookings/$bookingId/seat");
    final res = await http.patch(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"seatId": seatId}),
    );

    if (res.statusCode != 200) {
      throw Exception("Seat update failed (${res.statusCode}): ${res.body}");
    }
  }

  static Future<void> cancelBooking({
    required int bookingId,
  }) async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception("Not logged in (missing access token)");
    }

    final uri = Uri.parse("${AppConfig.baseUrl}/api/bookings/$bookingId/cancel");
    final res = await http.patch(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Cancel failed (${res.statusCode}): ${res.body}");
    }
  }
}
