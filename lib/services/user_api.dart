import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/user_model.dart';
import 'token_store.dart';

class UserApi {
  static const String profileEndpoint = "/api/auth/me";

  static Future<AppUser> fetchLoggedInUser() async {
    final token = await TokenStore.getAccessToken();
    final baseUrl = AppConfig.baseUrl;

    debugPrint(
      "ME CALL => $baseUrl$profileEndpoint | token=${token == null ? 'null' : 'present'}",
    );

    final res = await http
        .get(
          Uri.parse("${AppConfig.baseUrl}$profileEndpoint"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final data = decoded is Map && decoded["user"] != null ? decoded["user"] : decoded;
      return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("AUTH_EXPIRED");
    }

    throw Exception("Failed to load user profile (${res.statusCode})");
  }
}
