import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String? _runtimeBaseUrl;

  static void setRuntimeBaseUrl(String url) {
    if (url.trim().isEmpty) return;
    _runtimeBaseUrl = url.trim();
  }

  static String get baseUrl {
    if (_runtimeBaseUrl != null && _runtimeBaseUrl!.isNotEmpty) {
      return _runtimeBaseUrl!;
    }

    const override = String.fromEnvironment('BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;

    if (kIsWeb) {
      final host = Uri.base.host;
      final resolvedHost = (host.isEmpty || host == "localhost") ? "127.0.0.1" : host;
      return "http://$resolvedHost:4000";
    }
    if (Platform.isAndroid) return "http://10.0.2.2:4000"; // ✅ emulator default
    return "http://127.0.0.1:4000";
  }
}
