int jInt(dynamic v, {int def = 0}) {
  if (v == null) return def;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

double jDouble(dynamic v, {double def = 0}) {
  if (v == null) return def;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? def;
  return def;
}

bool jBool(dynamic v, {bool def = false}) {
  if (v == null) return def;
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == "true" || s == "1" || s == "yes") return true;
    if (s == "false" || s == "0" || s == "no") return false;
  }
  if (v is num) return v != 0;
  return def;
}

String jStr(dynamic v, {String def = ""}) {
  if (v == null) return def;
  if (v is String) return v;
  return v.toString();
}
