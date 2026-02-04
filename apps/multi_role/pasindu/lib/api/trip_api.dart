import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/trip_model.dart';

class TripApi {
  static String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static Future<List<Trip>> searchTrips({
    required String from,
    required String to,
    required DateTime date,
  }) async {
    final uri = Uri.parse(
      "${AppConfig.baseUrl}/api/trips"
      "?from=${Uri.encodeComponent(from)}"
      "&to=${Uri.encodeComponent(to)}"
      "&date=${_fmtDate(date)}",
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("Trip search failed (${res.statusCode}): ${res.body}");
    }

    final List data = jsonDecode(res.body) as List;
    return data.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }
    /// Get boarding stops allowed for a trip (bus stand → highway entrance)
  static Future<List<Map<String, dynamic>>> getBoardingStops(int tripId) async {
    final uri =
        Uri.parse("${AppConfig.baseUrl}/api/trips/$tripId/boarding-stops");

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception(
        "Boarding stops fetch failed (${res.statusCode}): ${res.body}",
      );
    }

    final List data = jsonDecode(res.body) as List;
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

}
