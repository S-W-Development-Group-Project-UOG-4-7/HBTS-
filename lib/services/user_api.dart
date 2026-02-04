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
<<<<<<< HEAD
=======
    final baseUrl = AppConfig.baseUrl;
>>>>>>> origin/develop

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
<<<<<<< HEAD
        .timeout(const Duration(seconds: 10)); // prevents infinite loading

    print("ME RESP => ${res.statusCode} | ${res.body}");
=======
        .timeout(const Duration(seconds: 10));
>>>>>>> origin/develop

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
