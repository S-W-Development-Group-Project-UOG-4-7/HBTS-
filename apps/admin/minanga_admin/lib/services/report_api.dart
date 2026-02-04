import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'token_store.dart';
import '../config.dart';

class ReportApi {
  // Android emulator → backend
  //static const String baseUrl = "http://10.0.2.2:4000/api";
   //Chrome emulator local
  static const String baseUrl = AppConfig.baseUrl; 

  /// Driver Status Report
  /// Returns: [{ status: "approved", total: 5 }, ...]
  static Future<List<Map<String, dynamic>>> driverStatus() async {
    final String? token = await TokenStore.getAccessToken();

    if (token == null) {
      throw Exception("Access token not found. Please login again.");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/admin/reports/drivers/status"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("Unauthorized. Admin access required.");
    }

    throw Exception(
      "Failed to load driver report (${response.statusCode})",
    );
  }

  static Future<Map<String, dynamic>> reportSummary({
    String? from,
    String? to,
  }) async {
    final String? token = await TokenStore.getAccessToken();

    if (token == null) {
      throw Exception("Access token not found. Please login again.");
    }

    final query = <String, String>{};
    if (from != null && from.isNotEmpty) query["from"] = from;
    if (to != null && to.isNotEmpty) query["to"] = to;

    final uri = Uri.parse("$baseUrl/admin/reports/summary")
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("Unauthorized. Admin access required.");
    }

    throw Exception(
      "Failed to load report (${response.statusCode})",
    );
  }

  static Future<Uint8List> downloadSummaryPdf({
    String? from,
    String? to,
  }) async {
    return _downloadBinary(
      path: "/admin/reports/summary/pdf",
      from: from,
      to: to,
    );
  }

  static Future<Uint8List> downloadSummaryExcel({
    String? from,
    String? to,
  }) async {
    return _downloadBinary(
      path: "/admin/reports/summary/excel",
      from: from,
      to: to,
    );
  }

  static Future<Uint8List> _downloadBinary({
    required String path,
    String? from,
    String? to,
  }) async {
    final String? token = await TokenStore.getAccessToken();

    if (token == null) {
      throw Exception("Access token not found. Please login again.");
    }

    final query = <String, String>{};
    if (from != null && from.isNotEmpty) query["from"] = from;
    if (to != null && to.isNotEmpty) query["to"] = to;

    final uri = Uri.parse("$baseUrl$path")
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(
      uri,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("Unauthorized. Admin access required.");
    }

    throw Exception(
      "Failed to download report (${response.statusCode})",
    );
  }
}
