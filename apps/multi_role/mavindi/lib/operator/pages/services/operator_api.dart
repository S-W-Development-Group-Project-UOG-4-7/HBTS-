import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  static Map<String, String> _authHeaders({bool json = true}) {
    final token = OperatorSession.token;
    final headers = <String, String>{
      "Accept": "application/json",
      if (json) "Content-Type": "application/json",
    };
    if (token == null || token.isEmpty) return headers;
    return {
      ...headers,
      "Authorization": "Bearer $token",
    };
  }

  static Future<http.Response> _sendMultipart({
    required Uri url,
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
  }) async {
    final request = http.MultipartRequest("POST", url);
    request.headers.addAll(_authHeaders(json: false));
    request.fields.addAll(fields);
    request.files.addAll(files);
    final streamed = await request.send().timeout(const Duration(seconds: 15));
    return http.Response.fromStream(streamed);
  }

  static List<Uri> _candidateLoginUrls() {
    final seen = <String>{};
    final candidates = <Uri>[];
    final base = Uri.parse(AppConfig.baseUrl);
    final scheme = base.scheme.isNotEmpty ? base.scheme : "http";

    void add(Uri uri) {
      final key = uri.origin;
      if (seen.add(key)) {
        candidates.add(uri.replace(path: "/api/operator/login"));
      }
    }

    if (base.host.isNotEmpty && base.hasPort) {
      add(base);
    }

    final hosts = <String>{
      if (base.host.isNotEmpty) base.host,
      "127.0.0.1",
      "localhost",
    };

    final ports = <int>{
      if (base.hasPort) base.port,
      if (!base.hasPort || base.port == 4000) 8000,
      4000,
    };

    for (final host in hosts) {
      for (final port in ports) {
        add(Uri(scheme: scheme, host: host, port: port));
      }
    }

    return candidates;
  }

  // ---------- AUTH ----------
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final body = jsonEncode({
      "email": email.trim(),
      "password": password,
    });

    http.Response? res;
    Object? lastError;

    for (final url in _candidateLoginUrls()) {
      try {
        final attempt = await http
            .post(url, headers: _jsonHeaders(), body: body)
            .timeout(const Duration(seconds: 8));

        if (attempt.statusCode == 200) {
          res = attempt;
          AppConfig.setRuntimeBaseUrl(url.origin);
          break;
        }

        if (attempt.statusCode == 400 ||
            attempt.statusCode == 401 ||
            attempt.statusCode == 403 ||
            attempt.statusCode >= 500) {
          throw Exception("Login failed (${attempt.statusCode}): ${_body(attempt)}");
        }

        lastError =
            Exception("Unexpected response (${attempt.statusCode}) from ${url.origin}");
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
    }

    if (res == null) {
      if (lastError != null) {
        throw Exception(
          "Cannot reach operator login service. ${lastError.toString()}",
        );
      }
      throw Exception("Cannot reach operator login service.");
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
    OperatorSession.operatorEmail = operator["email"]?.toString();

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
    String? email,
    String? idNumber,
    Uint8List? profileImageBytes,
    String? profileImageName,
    Uint8List? idCardImageBytes,
    String? idCardImageName,
  }) async {
    final url = _uri("/operator/drivers");
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email?.trim();
    final trimmedId = idNumber?.trim();
    final trimmedLicense = licenseNo?.trim();

    final hasFiles = profileImageBytes != null || idCardImageBytes != null;

    final res = hasFiles
        ? await _sendMultipart(
            url: url,
            fields: {
              "name": trimmedName,
              "phone": trimmedPhone,
              if (trimmedEmail != null && trimmedEmail.isNotEmpty) "email": trimmedEmail,
              if (trimmedId != null && trimmedId.isNotEmpty) "idNumber": trimmedId,
              if (trimmedLicense != null && trimmedLicense.isNotEmpty)
                "licenseNo": trimmedLicense,
            },
            files: [
              if (profileImageBytes != null)
                http.MultipartFile.fromBytes(
                  "profile",
                  profileImageBytes,
                  filename: profileImageName ?? "profile.jpg",
                ),
              if (idCardImageBytes != null)
                http.MultipartFile.fromBytes(
                  "idCard",
                  idCardImageBytes,
                  filename: idCardImageName ?? "id_card.jpg",
                ),
            ],
          )
        : await http.post(
            url,
            headers: _authHeaders(),
            body: jsonEncode({
              "name": trimmedName,
              "phone": trimmedPhone,
              "email": trimmedEmail,
              "idNumber": trimmedId,
              "licenseNo": trimmedLicense,
            }),
          );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception("Failed to create driver (${res.statusCode}): ${_body(res)}");
    }

    return Map<String, dynamic>.from(jsonDecode(_body(res)) as Map);
  }

  // ---------- CONDUCTORS ----------
  static Future<List<Map<String, dynamic>>> fetchConductors() async {
    final url = _uri("/operator/conductors");
    final res = await http.get(url, headers: _authHeaders());

    if (res.statusCode != 200) {
      throw Exception(
        "Failed to load conductors (${res.statusCode}): ${_body(res)}",
      );
    }

    final decoded = jsonDecode(_body(res));
    if (decoded is! List) {
      throw Exception("Conductors response is not a list: $decoded");
    }

    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createConductor({
    required String name,
    required String phone,
    required String email,
    required String idNumber,
    required int busId,
    Uint8List? profileImageBytes,
    String? profileImageName,
    Uint8List? idCardImageBytes,
    String? idCardImageName,
  }) async {
    final url = _uri("/operator/conductors");
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email.trim();
    final trimmedId = idNumber.trim();

    final hasFiles = profileImageBytes != null || idCardImageBytes != null;

    final res = hasFiles
        ? await _sendMultipart(
            url: url,
            fields: {
              "name": trimmedName,
              "phone": trimmedPhone,
              "email": trimmedEmail,
              "idNumber": trimmedId,
              "busId": busId.toString(),
            },
            files: [
              if (profileImageBytes != null)
                http.MultipartFile.fromBytes(
                  "profile",
                  profileImageBytes,
                  filename: profileImageName ?? "profile.jpg",
                ),
              if (idCardImageBytes != null)
                http.MultipartFile.fromBytes(
                  "idCard",
                  idCardImageBytes,
                  filename: idCardImageName ?? "id_card.jpg",
                ),
            ],
          )
        : await http.post(
            url,
            headers: _authHeaders(),
            body: jsonEncode({
              "name": trimmedName,
              "phone": trimmedPhone,
              "email": trimmedEmail,
              "idNumber": trimmedId,
              "busId": busId,
            }),
          );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(
        "Failed to create conductor (${res.statusCode}): ${_body(res)}",
      );
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

  static String _dateParam(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split("T").first;
  }
}
