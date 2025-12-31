import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const String _kToken = "token";
  static const String _kRole = "role";
  static const String _kOperatorId = "operator_id";

  // =======================
  // TOKEN
  // =======================
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  // =======================
  // ROLE
  // =======================
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  // =======================
  // LOGIN CHECKS
  // =======================
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> isAdmin() async {
    final role = await getRole();
    return role == "admin";
  }

  static Future<bool> isOperator() async {
    final role = await getRole();
    return role == "operator";
  }

  // =======================
  // OPERATOR ID
  // =======================
  static Future<void> saveOperatorId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOperatorId, id);
  }

  static Future<int?> getOperatorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kOperatorId);
  }

  // =======================
  // CLEAR SESSION (LOGOUT)
  // =======================
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRole);
    await prefs.remove(_kOperatorId);
  }
}
