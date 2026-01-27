import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import 'token_store.dart';

class TrackingSocketService {
  WebSocketChannel? _channel;

  Future<void> connect() async {
    final token = await TokenStore.getAccessToken();
    if (token == null || token.isEmpty) throw Exception("Missing access token");

    final base = AppConfig.baseUrl.replaceFirst('http', 'ws');
    final url = Uri.parse('$base/ws/tracking').replace(queryParameters: {
      'token': token,
    });

    _channel = WebSocketChannel.connect(url);
  }

  void subscribe({required int tripId, required int bookingId}) {
    _channel?.sink.add(jsonEncode({
      'type': 'subscribe',
      'tripId': tripId,
      'bookingId': bookingId,
    }));
  }

  void unsubscribe({required int tripId}) {
    _channel?.sink.add(jsonEncode({
      'type': 'unsubscribe',
      'tripId': tripId,
    }));
  }

  Stream<Map<String, dynamic>> stream() {
    if (_channel == null) throw Exception("Socket not connected");
    return _channel!.stream.map((e) => jsonDecode(e as String) as Map<String, dynamic>);
  }

  void close() {
    _channel?.sink.close();
    _channel = null;
  }
}
