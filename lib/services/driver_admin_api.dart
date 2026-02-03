import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'token_store.dart';

class DriverAdminApi {
  static Uri _u(String path, [Map<String, String>? query]) {
    return Uri.parse("${AppConfig.baseUrl}$path").replace(queryParameters: query);
  }

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

  static dynamic _decode(http.Response res) {
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  /// List drivers filtered by status (approved|pending|rejected) and optional search.
  static Future<List<dynamic>> list({
    String? status,
    String search = "",
  }) async {
    final uri = _u("/admin/drivers", {
      if (status != null && status.isNotEmpty) "status": status,
      if (search.isNotEmpty) "search": search,
    });

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

  /// Get single driver.
  static Future<Map<String, dynamic>> fetch(int id) async {
    final res = await http.get(_u("/admin/drivers/$id"), headers: await _headers());

    if (res.statusCode == 404) {
      throw Exception("Driver not found");
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Access denied. Admin login required.");
    }
    if (res.statusCode != 200) {
      throw Exception("Failed to load driver (${res.statusCode})");
    }

    final data = _decode(res);
    if (data is! Map<String, dynamic>) {
      throw Exception("Invalid driver data");
    }
    return data;
  }

  /// Update driver profile fields.
  static Future<Map<String, dynamic>> update(
    int id, {
    String? fullName,
    String? licenseNumber,
    String? phone,
    String? operatorName,
  }) async {
    final res = await http.put(
      _u("/admin/drivers/$id"),
      headers: await _headers(),
      body: jsonEncode({
        "fullName": fullName,
        "licenseNumber": licenseNumber,
        "phone": phone,
        "operatorName": operatorName,
      }),
    );

    if (res.statusCode == 404) {
      throw Exception("Driver not found");
    }
    if (res.statusCode != 200) {
      throw Exception("Failed to update driver (${res.statusCode})");
    }

    final data = _decode(res);
    if (data is! Map<String, dynamic>) {
      throw Exception("Invalid driver data");
    }
    return data;
  }

  /// Approve/Reject/Pend a driver.
  static Future<Map<String, dynamic>> updateStatus(
    int id,
    String status, {
    String? reason,
  }) async {
    final res = await http.put(
      _u("/admin/drivers/$id/status"),
      headers: await _headers(),
      body: jsonEncode({
        "status": status,
        "reason": reason,
      }),
    );

    if (res.statusCode == 404) {
      throw Exception("Driver not found");
    }
    if (res.statusCode != 200) {
      throw Exception("Failed to update status (${res.statusCode})");
    }

    final data = _decode(res);
    if (data is! Map<String, dynamic>) {
      throw Exception("Invalid driver data");
    }
    return data;
  }
}
