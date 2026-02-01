// lib/services/conductor_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'token_store.dart';

import '../models/conductor_bus_model.dart';
import '../models/conductor_active_trip_model.dart';
import '../models/conductor_booking_model.dart';
import '../models/conductor_trip_summary_model.dart';

class ConductorApi {
  static String get _base => "${AppConfig.baseUrl}/api/conductor";

  static Future<String> _token() async {
    final t = await TokenStore.getAccessToken();
    if (t == null || t.isEmpty) throw Exception("Missing access token");
    return t;
  }

  // ---------- low-level helpers ----------

  static Future<dynamic> _getAny(String url) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(url),
      headers: {"Authorization": "Bearer $token"},
    );

    final body = res.body.trim();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) return null;
      return jsonDecode(body);
    }

    throw Exception("GET failed (${res.statusCode}): $body");
  }

  static Future<Map<String, dynamic>> _getJsonMap(String url) async {
    final any = await _getAny(url);
    if (any == null) return <String, dynamic>{};
    if (any is Map<String, dynamic>) return any;
    if (any is Map) return Map<String, dynamic>.from(any);
    throw Exception("Expected JSON object but got: ${any.runtimeType}");
  }

  static Future<List<dynamic>> _getJsonList(String url) async {
    final any = await _getAny(url);
    if (any == null) return const [];
    if (any is List) return any;
    throw Exception("Expected JSON array but got: ${any.runtimeType}");
  }

  static Future<Map<String, dynamic>> _postJson(String url, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    final text = res.body.trim();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (text.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(text);
      if (decoded == null) return <String, dynamic>{};
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      // some endpoints might return non-map on success; wrap it
      return <String, dynamic>{"data": decoded};
    }

    throw Exception("POST failed (${res.statusCode}): $text");
  }

  // -------------------------
  // Conductor endpoints
  // -------------------------

  static Future<ConductorBus> getMyBus() async {
    final j = await _getJsonMap("$_base/me/bus");
    return ConductorBus.fromJson(j);
  }

  /// Returns null if no active trip.
  static Future<ConductorActiveTrip?> getMyActiveTrip() async {
    try {
      final any = await _getAny("$_base/me/active-trip");

      // backend returns null when no active trip (your controller does res.json(null))
      if (any == null) return null;

      if (any is Map) {
        final map = Map<String, dynamic>.from(any);
        if (map.isEmpty) return null;
        return ConductorActiveTrip.fromJson(map);
      }

      throw Exception("Expected object/null but got: ${any.runtimeType}");
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("(404)")) return null;
      rethrow;
    }
  }

  /// ✅ endpoint returns a plain JSON array
  static Future<List<ConductorTripSummary>> getMyTrips({required String dateYYYYMMDD}) async {
    final list = await _getJsonList("$_base/me/trips?date=$dateYYYYMMDD");
    return list
        .map((e) => ConductorTripSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<ConductorBooking>> getTripBookings({
    required int tripId,
    int page = 1,
    int limit = 30,
    String? status,   // boarded / not_boarded
    String? payment,  // cash_pending / paid / online_paid
    String? q,        // booking_id / seat / phone
  }) async {
    final qp = <String, String>{
      "page": "$page",
      "limit": "$limit",
      if (status != null && status.trim().isNotEmpty) "status": status.trim(),
      if (payment != null && payment.trim().isNotEmpty) "payment": payment.trim(),
      if (q != null && q.trim().isNotEmpty) "q": q.trim(),
    };

    final uri = Uri.parse("$_base/trips/$tripId/bookings").replace(queryParameters: qp);
    final j = await _getJsonMap(uri.toString());
    final items = (j["items"] as List?) ?? const [];
    return items
        .map((e) => ConductorBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // -------------------------
  // Trip control endpoints (shared /api/trips)
  // -------------------------

  static Future<void> startTrip(int tripId) async {
    await _postJson("${AppConfig.baseUrl}/api/trips/$tripId/start", {});
  }

  static Future<void> endTrip(int tripId) async {
    await _postJson("${AppConfig.baseUrl}/api/trips/$tripId/end", {});
  }

  static Future<void> cancelTrip(int tripId) async {
    await _postJson("${AppConfig.baseUrl}/api/trips/$tripId/cancel", {});
  }

  // -------------------------
  // Scan flow (MATCH BACKEND)
  // -------------------------

  /// Backend expects: { qr: string, tripId?: number }
  static Future<Map<String, dynamic>> scanVerify({
    required String qr,
    int? tripId,
  }) async {
    return _postJson("$_base/scan/verify", {
      "qr": qr,
      if (tripId != null) "tripId": tripId,
    });
  }

  /// Backend expects: { qr, tripId?, source?, collectCash?, amount?, clientActionId? }
  static Future<Map<String, dynamic>> scanCommit({
    required String qr,
    int? tripId,
    String source = "QR",
    bool collectCash = false,
    double? amount,
    String? clientActionId,
  }) async {
    return _postJson("$_base/scan/commit", {
      "qr": qr,
      if (tripId != null) "tripId": tripId,
      "source": source,
      "collectCash": collectCash,
      if (amount != null) "amount": amount,
      if (clientActionId != null) "clientActionId": clientActionId,
    });
  }

  // -------------------------
  // Booking actions (MATCH BACKEND)
  // -------------------------

  static Future<void> board({
    required int bookingId,
    required int tripId,
    String source = "MANUAL",
  }) async {
    await _postJson("$_base/bookings/$bookingId/board", {
      "tripId": tripId,
      "source": source,
    });
  }

  static Future<void> payCash({
    required int bookingId,
    required int tripId,
    required String clientActionId,
    double? amount,
  }) async {
    await _postJson("$_base/bookings/$bookingId/pay-cash", {
      "tripId": tripId,
      "clientActionId": clientActionId,
      if (amount != null) "amount": amount,
    });
  }
}
