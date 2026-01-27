import 'dart:async';
import 'dart:convert';
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

    print(
      "ME CALL => ${AppConfig.baseUrl}$profileEndpoint | token=${token == null ? 'null' : 'present'}",
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
=======
        .timeout(const Duration(seconds: 10));
>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e

    print("ME RESP => ${res.statusCode} | ${res.body}");

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final data = json['user'] ?? json;
      return AppUser.fromJson(Map<String, dynamic>.from(data));
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("AUTH_EXPIRED");
    }

    throw Exception("Failed to load user profile (${res.statusCode})");
  }
}

