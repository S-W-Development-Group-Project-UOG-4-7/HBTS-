import 'dart:convert';
import 'package:http/http.dart' as http;

import 'token_store.dart';
import '../config.dart';

class AdminApi {
  // 🌐 Backend base URL
  static const String baseUrl = AppConfig.baseUrl;
  // Android emulator:
  // static const String baseUrl = "http://10.0.2.2:4000/api";

  // =======================
  // AUTH HEADERS
  // =======================
  static Future<Map<String, String>> _headers() async {
    final token = await TokenStore.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception("Not authenticated. Please login again.");
    }

    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  // =======================
  // SAFE JSON DECODE
  // =======================
  static dynamic _decode(http.Response res) {
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  // =======================
  // GET PASSENGERS (SEARCH)
  // GET /admin/passengers?search=
  // =======================
  static Future<List<dynamic>> getPassengers(String search) async {
    final uri = Uri.parse(
      "$baseUrl/admin/passengers?search=${Uri.encodeQueryComponent(search)}",
    );

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load passengers (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // GET PASSENGER DETAILS
  // GET /admin/passengers/:id
  // =======================
  static Future<Map<String, dynamic>> fetchPassengerDetails(
    int userId,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/passengers/$userId");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load passenger (${res.statusCode})");
    }

    final data = _decode(res);
    if (data is! Map<String, dynamic>) {
      throw Exception("Invalid passenger data");
    }

    return data;
  }

  // =======================
  // GET PASSENGER BOOKINGS
  // GET /admin/passengers/:id/bookings
  // =======================
  static Future<List<dynamic>> fetchPassengerBookings(
    int userId,
  ) async {
    final uri =
        Uri.parse("$baseUrl/admin/passengers/$userId/bookings");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode == 404) {
      return []; // no bookings
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load bookings (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD PASSENGER
  // POST /admin/passengers
  // =======================
  static Future<void> addPassenger(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/passengers");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add passenger (${res.statusCode})");
    }
  }

  // =======================
  // UPDATE PASSENGER
  // PUT /admin/passengers/:id
  // =======================
  static Future<void> updatePassenger(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/passengers/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update passenger (${res.statusCode})");
    }
  }

  // =======================
  // DELETE PASSENGER
  // DELETE /admin/passengers/:id
  // =======================
  static Future<void> deletePassenger(int id) async {
    final uri = Uri.parse("$baseUrl/admin/passengers/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete passenger (${res.statusCode})");
    }
  }

  // =======================
  // GET COMPANIES
  // GET /admin/companies?search=
  // =======================
  static Future<List<dynamic>> getCompanies({String search = ""}) async {
    final query = <String, String>{};
    if (search.isNotEmpty) {
      query["search"] = search;
    }

    final uri = Uri.parse("$baseUrl/admin/companies")
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load companies (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD COMPANY
  // POST /admin/companies
  // =======================
  static Future<Map<String, dynamic>> addCompany(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/companies");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add company (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // UPDATE COMPANY
  // PUT /admin/companies/:id
  // =======================
  static Future<Map<String, dynamic>> updateCompany(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/companies/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update company (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // DELETE COMPANY
  // DELETE /admin/companies/:id
  // =======================
  static Future<void> deleteCompany(int id) async {
    final uri = Uri.parse("$baseUrl/admin/companies/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete company (${res.statusCode})");
    }
  }

  // =======================
  // GET OPERATORS (USERS ROLE_ID=5)
  // GET /admin/operators?search=
  // =======================
  static Future<List<dynamic>> getOperators({
    String search = "",
    int? companyId,
  }) async {
    final query = <String, String>{};
    if (search.isNotEmpty) {
      query["search"] = search;
    }
    if (companyId != null) {
      query["companyId"] = companyId.toString();
    }

    final uri = Uri.parse("$baseUrl/admin/operators")
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load operators (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD OPERATOR
  // POST /admin/operators
  // =======================
  static Future<Map<String, dynamic>> addOperator(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/operators");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add operator (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // UPDATE OPERATOR
  // PUT /admin/operators/:id
  // =======================
  static Future<Map<String, dynamic>> updateOperator(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/operators/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update operator (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // DELETE OPERATOR
  // DELETE /admin/operators/:id
  // =======================
  static Future<void> deleteOperator(int id) async {
    final uri = Uri.parse("$baseUrl/admin/operators/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete operator (${res.statusCode})");
    }
  }

  // =======================
  // GET CONDUCTORS
  // GET /admin/conductors?search=
  // =======================
  static Future<List<dynamic>> getConductors({String search = ""}) async {
    final query = <String, String>{};
    if (search.isNotEmpty) {
      query["search"] = search;
    }

    final uri = Uri.parse("$baseUrl/admin/conductors")
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load conductors (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD CONDUCTOR
  // POST /admin/conductors
  // =======================
  static Future<Map<String, dynamic>> addConductor(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/conductors");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      final decoded = _decode(res);
      final message =
          decoded is Map<String, dynamic> ? decoded["message"] : null;
      throw Exception(
        message ?? "Failed to add conductor (${res.statusCode})",
      );
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // UPDATE CONDUCTOR
  // PUT /admin/conductors/:id
  // =======================
  static Future<Map<String, dynamic>> updateConductor(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/conductors/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      final decoded = _decode(res);
      final message =
          decoded is Map<String, dynamic> ? decoded["message"] : null;
      throw Exception(
        message ?? "Failed to update conductor (${res.statusCode})",
      );
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // DELETE CONDUCTOR
  // DELETE /admin/conductors/:id
  // =======================
  static Future<void> deleteConductor(int id) async {
    final uri = Uri.parse("$baseUrl/admin/conductors/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete conductor (${res.statusCode})");
    }
  }

  // =======================
  // ADD ADMIN-CREATED USER (ROLE_ID = 2)
  // POST /admin/users
  // =======================
  static Future<Map<String, dynamic>> addAdminUser(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/users");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      final decoded = _decode(res);
      final message =
          decoded is Map<String, dynamic> ? decoded["message"] : null;
      throw Exception(message ?? "Failed to add user (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // GET BUSES
  // GET /admin/buses
  // =======================
  static Future<List<dynamic>> getBuses({
    int? busId,
    int? operatorId,
    String? licensePlateNo,
    String? routeNo,
    int? capacity,
    String? serviceType,
  }) async {
    final query = <String, String>{};
    if (busId != null) query["busId"] = busId.toString();
    if (operatorId != null) query["operatorId"] = operatorId.toString();
    if (licensePlateNo != null && licensePlateNo.isNotEmpty) {
      query["licensePlateNo"] = licensePlateNo;
    }
    if (routeNo != null && routeNo.isNotEmpty) {
      query["routeNo"] = routeNo;
    }
    if (capacity != null) query["capacity"] = capacity.toString();
    if (serviceType != null && serviceType.isNotEmpty) {
      query["serviceType"] = serviceType;
    }

    final uri = Uri.parse("$baseUrl/admin/buses")
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load buses (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD BUS
  // POST /admin/buses
  // =======================
  static Future<Map<String, dynamic>> addBus(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/buses");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add bus (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // UPDATE BUS
  // PUT /admin/buses/:id
  // =======================
  static Future<Map<String, dynamic>> updateBus(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/buses/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update bus (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // DELETE BUS (SOFT DELETE)
  // DELETE /admin/buses/:id
  // =======================
  static Future<void> deleteBus(int id) async {
    final uri = Uri.parse("$baseUrl/admin/buses/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete bus (${res.statusCode})");
    }
  }

  // =======================
  // RESTORE BUS (SOFT DELETE)
  // PUT /admin/buses/:id/restore
  // =======================
  static Future<void> restoreBus(int id) async {
    final uri = Uri.parse("$baseUrl/admin/buses/$id/restore");

    final res = await http.put(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to restore bus (${res.statusCode})");
    }
  }

  // =======================
  // BUS HISTORY (DELETED)
  // GET /admin/buses/history
  // =======================
  static Future<List<dynamic>> getBusHistory() async {
    final uri = Uri.parse("$baseUrl/admin/buses/history");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load bus history (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // GET ROUTES
  // GET /admin/routes
  // =======================
  static Future<List<dynamic>> getRoutes({
    int? routeId,
    String? name,
    String? code,
    String? origin,
    String? destination,
    String? status,
  }) async {
    final query = <String, String>{};
    if (routeId != null) query["routeId"] = routeId.toString();
    if (name != null && name.isNotEmpty) query["name"] = name;
    if (code != null && code.isNotEmpty) query["code"] = code;
    if (origin != null && origin.isNotEmpty) query["origin"] = origin;
    if (destination != null && destination.isNotEmpty) {
      query["destination"] = destination;
    }
    if (status != null && status.isNotEmpty) query["status"] = status;

    final uri = Uri.parse("$baseUrl/admin/routes")
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load routes (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD ROUTE
  // POST /admin/routes
  // =======================
  static Future<Map<String, dynamic>> addRoute(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/routes");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add route (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // UPDATE ROUTE
  // PUT /admin/routes/:id
  // =======================
  static Future<Map<String, dynamic>> updateRoute(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/routes/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update route (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // DELETE ROUTE (SOFT DELETE)
  // DELETE /admin/routes/:id
  // =======================
  static Future<void> deleteRoute(int id) async {
    final uri = Uri.parse("$baseUrl/admin/routes/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete route (${res.statusCode})");
    }
  }

  // =======================
  // RESTORE ROUTE (SOFT DELETE)
  // PUT /admin/routes/:id/restore
  // =======================
  static Future<void> restoreRoute(int id) async {
    final uri = Uri.parse("$baseUrl/admin/routes/$id/restore");

    final res = await http.put(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to restore route (${res.statusCode})");
    }
  }

  // =======================
  // ROUTE HISTORY (DELETED)
  // GET /admin/routes/history
  // =======================
  static Future<List<dynamic>> getRouteHistory() async {
    final uri = Uri.parse("$baseUrl/admin/routes/history");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load route history (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // GET TRIPS
  // GET /admin/trips
  // =======================
  static Future<List<dynamic>> getTrips({
    int? tripId,
    int? routeId,
    int? operatorId,
    int? busId,
    int? driverId,
    String? status,
    String? tripDate,
  }) async {
    final query = <String, String>{};
    if (tripId != null) query["tripId"] = tripId.toString();
    if (routeId != null) query["routeId"] = routeId.toString();
    if (operatorId != null) query["operatorId"] = operatorId.toString();
    if (busId != null) query["busId"] = busId.toString();
    if (driverId != null) query["driverId"] = driverId.toString();
    if (status != null && status.isNotEmpty) query["status"] = status;
    if (tripDate != null && tripDate.isNotEmpty) query["tripDate"] = tripDate;

    final uri = Uri.parse("$baseUrl/admin/trips")
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load trips (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD TRIP
  // POST /admin/trips
  // =======================
  static Future<Map<String, dynamic>> addTrip(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/trips");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add trip (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // UPDATE TRIP
  // PUT /admin/trips/:id
  // =======================
  static Future<Map<String, dynamic>> updateTrip(
    int id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/trips/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update trip (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // DELETE TRIP (SOFT DELETE)
  // DELETE /admin/trips/:id
  // =======================
  static Future<void> deleteTrip(int id) async {
    final uri = Uri.parse("$baseUrl/admin/trips/$id");

    final res = await http.delete(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete trip (${res.statusCode})");
    }
  }

  // =======================
  // RESTORE TRIP (SOFT DELETE)
  // PUT /admin/trips/:id/restore
  // =======================
  static Future<void> restoreTrip(int id) async {
    final uri = Uri.parse("$baseUrl/admin/trips/$id/restore");

    final res = await http.put(
      uri,
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to restore trip (${res.statusCode})");
    }
  }

  // =======================
  // TRIP HISTORY (DELETED)
  // GET /admin/trips/history
  // =======================
  static Future<List<dynamic>> getTripHistory() async {
    final uri = Uri.parse("$baseUrl/admin/trips/history");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load trip history (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // TRIP STOPS
  // GET /admin/trips/:id/stops
  // =======================
  static Future<List<dynamic>> getTripStops(int tripId) async {
    final uri = Uri.parse("$baseUrl/admin/trips/$tripId/stops");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load trip stops (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ADD TRIP STOP
  // POST /admin/trips/:id/stops
  // =======================
  static Future<Map<String, dynamic>> addTripStop(
    int tripId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse("$baseUrl/admin/trips/$tripId/stops");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      throw Exception("Failed to add trip stop (${res.statusCode})");
    }

    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // =======================
  // TRIP LOCATION HISTORY
  // GET /admin/trips/:id/location-history
  // =======================
  static Future<List<dynamic>> getTripLocationHistory(int tripId) async {
    final uri =
        Uri.parse("$baseUrl/admin/trips/$tripId/location-history");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load trip location history (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }

  // =======================
  // ASSIGNABLE DRIVERS
  // GET /admin/trips/assignable-drivers
  // =======================
  static Future<List<dynamic>> getAssignableDrivers() async {
    final uri = Uri.parse("$baseUrl/admin/trips/assignable-drivers");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }

    if (res.statusCode != 200) {
      throw Exception("Failed to load drivers (${res.statusCode})");
    }

    final data = _decode(res);
    return data is List ? data : [];
  }
}
