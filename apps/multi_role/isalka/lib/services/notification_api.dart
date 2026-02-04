import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'token_store.dart';

class NotificationApi {
  static String get _base => "${AppConfig.baseUrl}/api/notifications";

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
  final token = await TokenStore.getAccessToken();
  if (token == null || token.isEmpty) throw Exception("Missing access token");

  final res = await http.get(
    Uri.parse("$_base/me"),
    headers: {"Authorization": "Bearer $token"},
  );

  if (res.statusCode == 200) {
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  throw Exception("Failed to load notifications (${res.statusCode}): ${res.body}");
}

  static Future<void> markAsRead(String id) async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) throw Exception("Missing access token");

    final res = await http.patch(
      Uri.parse("$_base/me/$id/read"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Mark as read failed (${res.statusCode}): ${res.body}");
    }
  }
}
