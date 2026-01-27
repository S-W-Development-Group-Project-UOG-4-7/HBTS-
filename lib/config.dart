import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;

    if (kIsWeb) return "http://localhost:4000";
    if (Platform.isAndroid) return "http://10.0.2.2:4000"; // ✅ emulator default
    return "http://localhost:4000";
  }
}
