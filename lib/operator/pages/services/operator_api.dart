import 'dart:convert';
import 'package:http/http.dart' as http;
import 'utils/operator_session.dart'; // ✅ correct for your folder structure


class OperatorApi {
  static const String baseUrl = "http://10.0.2.2:8000";

  static Uri _uri(String path) => Uri.parse("$baseUrl$path");

  static String _body(http.Response res) => utf8.decode(res.bodyBytes);

  static Map<String, String> _jsonHeaders() => const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

  // ---------- AUTH ----------
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = _uri("/operator/login"); // keep your endpoint

    final res = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        "email": email.trim(),
        "password": password,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Login failed (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));

    if (decoded is! Map) {
      throw Exception("Login response is not a JSON object: $decoded");
    }

    final data = Map<String, dynamic>.from(decoded);

    final token = data["token"];
    final operatorRaw = data["operator"];

    if (token == null) {
      throw Exception('Login response missing "token": $data');
    }
    if (operatorRaw is! Map) {
      throw Exception('Login response missing/invalid "operator": $data');
    }

    final operator = Map<String, dynamic>.from(operatorRaw);

    OperatorSession.token = token.toString();

    final idStr = operator["id"]?.toString();
    OperatorSession.operatorId = int.tryParse(idStr ?? "");

    OperatorSession.operatorName = operator["name"]?.toString();

    if (OperatorSession.operatorId == null) {
      throw Exception('Invalid operator id from backend: ${operator["id"]}');
    }

    return data;
  }

  // ---------- OPERATOR DETAILS ----------
  static Future<Map<String, dynamic>> fetchOperatorDetails(int operatorId) async {
    final url = _uri("/operator/$operatorId");

    final res = await http.get(
      url,
      headers: _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load operator (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));
    if (decoded is! Map) {
      throw Exception("Operator details response is not a JSON object: $decoded");
    }
    return Map<String, dynamic>.from(decoded);
  }

  // ---------- ASSIGNED BOOKINGS ----------
  static Future<List<Map<String, dynamic>>> fetchAssignedBookings(int operatorId) async {
    final url = _uri("/operator/$operatorId/assigned-bookings");

    final res = await http.get(
      url,
      headers: _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load bookings (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded["bookings"] is List) {
      list = decoded["bookings"] as List;
    } else {
      throw Exception("Unexpected bookings response shape: $decoded");
    }

    // Ensure each booking is a Map<String, dynamic>
    return list.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      throw Exception("Booking item is not a JSON object: $e");
    }).toList();
  }

  // ---------- UPDATE BOOKING STATUS ----------
  static Future<void> updateBookingStatus({
    required int bookingId,
    required String status,
  }) async {
    final url = _uri("/operator/bookings/$bookingId/status");

    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({"status": status}),
    );

    // Some APIs return 204 No Content for success too
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception("Failed to update booking (${res.statusCode}): ${_body(res)}");
    }
  }

  static Map<String, String> _authHeaders() {
    final token = OperatorSession.token;
    if (token == null || token.isEmpty) {
      return _jsonHeaders();
    }
    return {
      ..._jsonHeaders(),
      "Authorization": "Bearer $token",
    };
  }
}
