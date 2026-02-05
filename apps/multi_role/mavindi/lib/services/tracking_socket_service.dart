import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import 'token_store.dart';

class TrackingSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  // Reconnect state
  bool _connecting = false;
  bool _closed = false;
  Timer? _reconnectTimer;
  int _retries = 0;

  // Last subscription (auto re-subscribe after reconnect)
  int? _lastTripId;
  int? _lastBookingId;

  Future<void> connect() async {
    // Close any previous connection before creating a new one
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _closed = false;
    if (_connecting) return;
    _connecting = true;
    try {
      final token = await TokenStore.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception("Missing access token");
      }

      // Build WS URL safely even if baseUrl contains a path (e.g., /api)
      final httpUri = Uri.parse(AppConfig.baseUrl);
      final wsUri = httpUri.replace(
        scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/tracking',
        queryParameters: {'token': token},
      );

      // Establish channel
      _channel = WebSocketChannel.connect(wsUri);

      // Listen and forward
      await _wsSub?.cancel();
      _wsSub = _channel!.stream.listen(
        (event) {
          _retries = 0; // reset on successful activity
          try {
            final map = jsonDecode(event as String) as Map<String, dynamic>;
            _controller.add(map);
          } catch (_) {
            // ignore malformed frames
          }
        },
        onError: (e, st) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Re-subscribe if we had an active sub
      if (_lastTripId != null && _lastBookingId != null) {
        subscribe(tripId: _lastTripId!, bookingId: _lastBookingId!);
      }
    } finally {
      _connecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _wsSub?.cancel();
    _wsSub = null;
    _channel = null;

    // Exponential backoff up to 10s
    final delayMs = (1000 * (1 << (_retries.clamp(0, 3)))).clamp(1000, 10000).toInt();
    _retries++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_closed) return;
      await connect();
    });
  }

  void subscribe({required int tripId, required int bookingId}) {
    _lastTripId = tripId;
    _lastBookingId = bookingId;
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'subscribe',
        'tripId': tripId,
        'bookingId': bookingId,
      }));
    } catch (_) {}
  }

  void unsubscribe({required int tripId}) {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'unsubscribe',
        'tripId': tripId,
      }));
    } catch (_) {}
    // keep lastTripId/bookingId so reconnect can still restore if caller resubscribes later
  }

  Stream<Map<String, dynamic>> stream() {
    return _controller.stream;
  }

  void close() {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    // Do not close broadcast controller; keep service reusable in app lifetime
  }
}
