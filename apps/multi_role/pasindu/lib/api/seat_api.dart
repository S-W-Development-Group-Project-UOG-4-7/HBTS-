import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/seat_model.dart';

class SeatApi {
  static Future<List<Seat>> getTripSeats(int tripId) async {
    final uri = Uri.parse("${AppConfig.baseUrl}/api/trips/$tripId/seats");
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception("Seats fetch failed (${res.statusCode}): ${res.body}");
    }

    final List data = jsonDecode(res.body) as List;
    return data.map((e) => Seat.fromJson(e as Map<String, dynamic>)).toList();
  }
}
