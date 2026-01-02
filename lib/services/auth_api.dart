import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthApi {
  // Helper to build URLs
  static Uri _u(String path) => Uri.parse("${AppConfig.baseUrl}/api$path");

  // Safe JSON decode
  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {"message": res.body};
    }
  }

  // =======================
  // PASSENGER SIGNUP
  // POST /auth/passenger/signup
  // =======================
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      _u("/auth/passenger/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "fullName": fullName,
        "email": email,
        "phone": phone,
        "password": password,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Signup failed");
  }

  // =======================
  // VERIFY SIGNUP OTP
  // POST /auth/passenger/signup/verify-otp
  // =======================
  static Future<Map<String, dynamic>> verifySignupOtp({
    required int challengeId,
    required String otp,
  }) async {
    final res = await http.post(
      _u("/auth/passenger/signup/verify-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "challengeId": challengeId,
        "otp": otp,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "OTP verification failed");
  }

  // =======================
  // PASSENGER LOGIN
  // POST /auth/passenger/login
  // =======================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _u("/auth/passenger/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Login failed");
  }

  // =======================
  // VERIFY LOGIN OTP
  // POST /auth/passenger/login/verify-otp
  // =======================
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String tempToken,
    required int challengeId,
    required String otp,
  }) async {
    final res = await http.post(
      _u("/auth/passenger/login/verify-otp"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $tempToken",
      },
      body: jsonEncode({
        "challengeId": challengeId,
        "otp": otp,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Login OTP verification failed");
  }


  // =======================
  // ADMIN LOGIN
  // POST /auth/admin/login
  // =======================
  static Future<Map<String, dynamic>> adminLogin({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _u("/auth/admin/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Admin login failed");
  }

  // =======================
  // VERIFY ADMIN LOGIN OTP
  // POST /auth/admin/login/verify-otp
  // =======================
  static Future<Map<String, dynamic>> verifyAdminLoginOtp({
    required String tempToken,
    required int challengeId,
    required String otp,
  }) async {
    final res = await http.post(
      _u("/auth/admin/login/verify-otp"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $tempToken",
      },
      body: jsonEncode({
        "challengeId": challengeId,
        "otp": otp,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Admin OTP verification failed");
  }
}
  
