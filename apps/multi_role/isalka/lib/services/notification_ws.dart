import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/notification_model.dart';
import 'token_store.dart';

class NotificationWS {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required void Function(PassengerNotification n) onNotification,
    void Function()? onDisconnected,
  }) async {
    if (_channel != null) return;

    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) {
      onDisconnected?.call();
      return;
    }

    final base = AppConfig.baseUrl; // http://...:4000
    final wsBase = base.replaceFirst("http://", "ws://").replaceFirst("https://", "wss://");
    final url = "$wsBase/ws/notifications?token=${Uri.encodeComponent(token)}";

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _sub = _channel!.stream.listen(
      (event) {
        try {
          final decoded = jsonDecode(event);
          if (decoded is! Map) return;
          if (decoded["event"] != "notification") return;

          final payload = Map<String, dynamic>.from(decoded["payload"]);
          final n = PassengerNotification.fromJson(payload);
          onNotification(n);
        } catch (_) {}
      },
      onDone: () => _handleDisconnect(onDisconnected),
      onError: (_) => _handleDisconnect(onDisconnected),
      cancelOnError: true,
    );
  }

  void _handleDisconnect(void Function()? cb) {
    disconnect();
    cb?.call();
  }

  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }
}
