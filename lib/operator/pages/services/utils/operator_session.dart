class OperatorSession {
  // Store in memory for now (simple).
  // Later you can upgrade to SharedPreferences.
  static String? token;
  static int? operatorId;
  static String? operatorName;

  static bool get isLoggedIn => token != null && operatorId != null;

  static void clear() {
    token = null;
    operatorId = null;
    operatorName = null;
  }
}
