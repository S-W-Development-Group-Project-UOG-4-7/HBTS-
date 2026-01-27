import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  // =======================
  // SECURE STORAGE INSTANCE
  // =======================
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

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
    return await _storage.read(key: _accessTokenKey);
  }

  // =======================
  // REFRESH TOKEN
  // =======================
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
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
  }

  // =======================
  // ROLE HANDLING (SAFE)
  // =======================
  /// Accepts role name ("admin", "passenger", "operator", "driver")
  /// OR numeric role_id as string/int (e.g., 2, "2")
  static Future<void> saveRole(dynamic role) async {
    final roleValue = role.toString();
    await _storage.write(
      key: _roleKey,
      value: roleValue,
    );
  }

  static Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  /// Admin role check (string OR role_id supported)
  static Future<bool> isAdmin() async {
    final role = await getRole();
    if (role == null) return false;

    // keep role_id check only if your DB uses 2 for admin (as you had)
    return role == "admin" || role == "2";
  }

  /// Staff roles check (admin/operator/driver)
  static Future<bool> isStaff() async {
    final role = await getRole();
    if (role == null) return false;

    return role == "admin" ||
        role == "operator" ||
        role == "driver" ||
        // optional numeric role_ids if you ever store them
        role == "2";
  }

  static Future<bool> isPassenger() async {
    final role = await getRole();
    if (role == null) return false;

    return role == "passenger";
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

    // ignore: avoid_print
    print("🔐 ACCESS TOKEN: ${access != null ? 'EXISTS' : 'NULL'}");
    // ignore: avoid_print
    print("🔄 REFRESH TOKEN: ${refresh != null ? 'EXISTS' : 'NULL'}");
    // ignore: avoid_print
    print("👤 ROLE: $role");
  }

  // =======================
  // LOGOUT / CLEAR STORAGE
  // =======================
  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _roleKey);
  }
}