import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) return "http://localhost:4000";     // Chrome/Web
    if (Platform.isAndroid) return "http://10.0.2.2:4000"; // Android emulator
    return "http://localhost:4000";                 // Windows/macOS/iOS sim
  }
}
