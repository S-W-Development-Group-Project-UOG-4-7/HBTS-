import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../config.dart';
import 'token_store.dart';
import '../config.dart'; // ✅ ADD (update path if needed)

class UserApi {
  static const String profileEndpoint = "/api/auth/me";

  static Future<AppUser> fetchLoggedInUser() async {
    final token = await TokenStore.getAccessToken();
    final baseUrl = AppConfig.baseUrl; // ✅ use config

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
      final data = json['user'] ?? json;
      return AppUser.fromJson(Map<String, dynamic>.from(data));
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("AUTH_EXPIRED");
    }

    throw Exception("Failed to load user profile (${res.statusCode})");
  }
}

