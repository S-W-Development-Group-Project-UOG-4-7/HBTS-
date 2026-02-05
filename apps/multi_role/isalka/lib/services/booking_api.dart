import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'token_store.dart';

class BookingApi {
  static String get _base => "${AppConfig.baseUrl}/api/bookings";

  static Future<Map<String, dynamic>> getBookingTracking(int bookingId) async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) throw Exception("Missing access token");

    final res = await http.get(
      Uri.parse("$_base/$bookingId/tracking"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }

    throw Exception("Failed to load tracking (${res.statusCode}): ${res.body}");
  }
}
