import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';

class ReportApi {
  // Android emulator → backend
  //static const String baseUrl = "http://10.0.2.2:4000";
   //Chrome emulator local
  static const String baseUrl = "http://localhost:4000"; 

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
}
