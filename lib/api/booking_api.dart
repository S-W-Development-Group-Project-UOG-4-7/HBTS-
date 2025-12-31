import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/token_store.dart';

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
}
