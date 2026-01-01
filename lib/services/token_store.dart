import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  // =======================
  // SECURE STORAGE INSTANCE
  // =======================
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();
  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // =======================
  // STORAGE KEYS
  // =======================
  static const String _accessTokenKey = "accessToken";
  static const String _refreshTokenKey = "refreshToken";
  static const String _roleKey = "role";

  // =======================
  // ACCESS TOKEN
  // =======================
  static Future<String?> getAccessToken() async {
    final secure = await _storage.read(key: _accessTokenKey);
    if (secure != null && secure.isNotEmpty) return secure;

    final prefs = await _prefs;
    return prefs.getString(_accessTokenKey);
  }

  // =======================
  // REFRESH TOKEN
  // =======================
  static Future<String?> getRefreshToken() async {
    final secure = await _storage.read(key: _refreshTokenKey);
    if (secure != null && secure.isNotEmpty) return secure;

    final prefs = await _prefs;
    return prefs.getString(_refreshTokenKey);
  }

  // =======================
  // SAVE TOKENS
  // =======================
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    await _storage.write(
      key: _refreshTokenKey,
      value: refreshToken,
    );

    final prefs = await _prefs;
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Convenience for single-token flows (keeps older callers working)
  static Future<void> saveToken(String accessToken) async {
    await _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    final prefs = await _prefs;
    await prefs.setString(_accessTokenKey, accessToken);
  }

  // =======================
  // ROLE HANDLING (SAFE)
  // =======================
  /// Accepts "admin", "passenger" OR numeric role_id (2, 1, etc.)
  static Future<void> saveRole(dynamic role) async {
    final roleValue = role.toString();
    await _storage.write(
      key: _roleKey,
      value: roleValue,
    );

    final prefs = await _prefs;
    await prefs.setString(_roleKey, roleValue);
  }

  static Future<String?> getRole() async {
    final secure = await _storage.read(key: _roleKey);
    if (secure != null && secure.isNotEmpty) return secure;

    final prefs = await _prefs;
    return prefs.getString(_roleKey);
  }

  /// Admin role check (string OR role_id supported)
  static Future<bool> isAdmin() async {
    final role = await getRole();

    if (role == null) return false;

    return role == "admin" || role == "2";
  }

  // =======================
  // AUTH STATE
  // =======================
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // =======================
  // DEBUG HELPERS (OPTIONAL)
  // =======================
  static Future<void> debugPrintTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    final role = await getRole();

    debugPrint("🔐 ACCESS TOKEN: ${access != null ? 'EXISTS' : 'NULL'}");
    debugPrint("🔄 REFRESH TOKEN: ${refresh != null ? 'EXISTS' : 'NULL'}");
    debugPrint("👤 ROLE: $role");
  }

  // =======================
  // LOGOUT / CLEAR STORAGE
  // =======================
  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _roleKey);

    final prefs = await _prefs;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_roleKey);
  }
}
