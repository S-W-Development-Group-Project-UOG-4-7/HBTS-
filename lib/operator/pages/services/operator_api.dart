import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config.dart';
import 'utils/operator_session.dart'; // ✅ correct for your folder structure


class OperatorApi {
  static Uri _uri(String path) => Uri.parse("${AppConfig.baseUrl}/api$path");

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
  static Future<Map<String, dynamic>> fetchOperatorDetails() async {
    final url = _uri("/operator/me");

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

  // ---------- ASSIGNED TRIPS ----------
  static Future<List<Map<String, dynamic>>> fetchAssignedTrips({
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      params["status"] = status.trim();
    }
    if (from != null) {
      params["from"] = _dateParam(from);
    }
    if (to != null) {
      params["to"] = _dateParam(to);
    }

    final base = _uri("/operator/trips/assigned/all");
    final url = params.isEmpty ? base : base.replace(queryParameters: params);

    final res = await http.get(
      url,
      headers: _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load assigned trips (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded["trips"] is List) {
      list = decoded["trips"] as List;
    } else {
      throw Exception("Unexpected assigned trips response shape: $decoded");
    }

    // Ensure each trip is a Map<String, dynamic>
    return list.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      throw Exception("Trip item is not a JSON object: $e");
    }).toList();
  }

  // ---------- BUSES ----------
  static Future<List<Map<String, dynamic>>> fetchBuses() async {
    final url = _uri("/operator/buses");
    final res = await http.get(url, headers: _authHeaders());

    if (res.statusCode != 200) {
      throw Exception("Failed to load buses (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));
    if (decoded is! List) {
      throw Exception("Buses response is not a list: $decoded");
    }

    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createBus({
    required String plateNo,
    int? capacity,
    String? model,
    String? serviceType,
  }) async {
    final url = _uri("/operator/buses");
    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        "licensePlateNo": plateNo,
        "capacity": capacity,
        "model": model,
        "serviceType": serviceType,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception("Failed to create bus (${res.statusCode}): ${_body(res)}");
    }

    return Map<String, dynamic>.from(jsonDecode(_body(res)) as Map);
  }

  // ---------- DRIVERS ----------
  static Future<List<Map<String, dynamic>>> fetchDrivers() async {
    final url = _uri("/operator/drivers");
    final res = await http.get(url, headers: _authHeaders());

    if (res.statusCode != 200) {
      throw Exception("Failed to load drivers (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));
    if (decoded is! List) {
      throw Exception("Drivers response is not a list: $decoded");
    }

    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createDriver({
    required String name,
    required String phone,
    String? licenseNo,
  }) async {
    final url = _uri("/operator/drivers");
    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        "name": name,
        "phone": phone,
        "licenseNo": licenseNo,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception("Failed to create driver (${res.statusCode}): ${_body(res)}");
    }

    return Map<String, dynamic>.from(jsonDecode(_body(res)) as Map);
  }

  static Future<void> assignDriverToBus({
    required int driverId,
    required int busId,
  }) async {
    final url = _uri("/operator/drivers/$driverId/assign");
    final res = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({"busId": busId}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to assign driver (${res.statusCode}): ${_body(res)}");
    }
  }

  // ---------- PLATFORM ALLOCATION ----------
  static Future<List<Map<String, dynamic>>> fetchPlatforms() async {
    final url = _uri("/operator/platforms");
    final res = await http.get(url, headers: _authHeaders());

    if (res.statusCode != 200) {
      throw Exception("Failed to load platforms (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));
    if (decoded is! List) {
      throw Exception("Platforms response is not a list: $decoded");
    }

    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createPlatform({
    required int platformNumber,
    String? terminalName,
    String? name,
  }) async {
    final url = _uri("/operator/platforms");
    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        "platformNumber": platformNumber,
        "terminalName": terminalName,
        "name": name,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception("Failed to create platform (${res.statusCode}): ${_body(res)}");
    }

    return Map<String, dynamic>.from(jsonDecode(_body(res)) as Map);
  }

  // ---------- ROUTES ----------
  static Future<List<Map<String, dynamic>>> fetchRoutes() async {
    final url = _uri("/operator/routes");
    final res = await http.get(url, headers: _authHeaders());

    if (res.statusCode != 200) {
      throw Exception("Failed to load routes (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));
    if (decoded is! List) {
      throw Exception("Routes response is not a list: $decoded");
    }

    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createRoute({
    required String from,
    required String to,
    String? name,
    num? distanceKm,
  }) async {
    final url = _uri("/operator/routes");
    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        "routeName": name,
        "fromLocation": from,
        "toLocation": to,
        "distanceKm": distanceKm,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception("Failed to create route (${res.statusCode}): ${_body(res)}");
    }

    return Map<String, dynamic>.from(jsonDecode(_body(res)) as Map);
  }

  // ---------- TICKET VALIDATION ----------
  static Future<Map<String, dynamic>> validateTicket({
    int? bookingId,
    String? qrCode,
  }) async {
    final url = _uri("/operator/tickets/validate");
    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        "bookingId": bookingId,
        "qrCode": qrCode,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Validation failed (${res.statusCode}): ${_body(res)}");
    }

    return Map<String, dynamic>.from(jsonDecode(_body(res)) as Map);
  }

  // ---------- UPDATE TRIP STATUS ----------
  static Future<void> updateTripStatus({
    required int tripId,
    required String status,
  }) async {
    final url = _uri("/operator/trips/$tripId");

    final res = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({"status": status}),
    );

    // Some APIs return 204 No Content for success too
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception("Failed to update trip (${res.statusCode}): ${_body(res)}");
    }
  }

  // ---------- BUS BOOKING STATS ----------
  static Future<List<Map<String, dynamic>>> fetchBusBookingCounts({
    required DateTime from,
    required DateTime to,
  }) async {
    final base = _uri("/operator/buses/booking-counts");
    final url = base.replace(
      queryParameters: {
        "from": _dateParam(from),
        "to": _dateParam(to),
      },
    );

    final res = await http.get(url, headers: _authHeaders());

    if (res.statusCode != 200) {
      throw Exception("Failed to load bus booking counts (${res.statusCode}): ${_body(res)}");
    }

    final decoded = jsonDecode(_body(res));
    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded["buses"] is List) {
      list = decoded["buses"] as List;
    } else {
      throw Exception("Bus booking counts response is not a list: $decoded");
    }

    return list.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      throw Exception("Bus booking item is not a JSON object: $e");
    }).toList();
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

  static String _dateParam(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split("T").first;
  }
}
