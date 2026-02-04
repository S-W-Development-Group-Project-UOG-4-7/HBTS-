import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import 'token_store.dart';

enum RealtimeConnStatus { disconnected, connecting, connected, reconnecting }

class RealtimeEvent {
  final String type;
  final int? operatorId;
  final int? busId;
  final int? tripId;
  final String? busKey;

  RealtimeEvent({
    required this.type,
    this.operatorId,
    this.busId,
    this.tripId,
    this.busKey,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> j) {
  int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  return RealtimeEvent(
    type: (j["type"] ?? "").toString(),
    operatorId: toInt(j["operatorId"]),
    busId: toInt(j["busId"]),
    tripId: toInt(j["tripId"]),
    busKey: j["busKey"]?.toString(),
  );
}


  bool get isConnected => type == "CONNECTED";
  bool get isTripStarted => type == "TRIP_STARTED";
  bool get isTripEnded => type == "TRIP_ENDED";
  bool get isTripCancelled => type == "TRIP_CANCELLED";
}

class RealtimeWsService {
  WebSocket? _ws;
  Timer? _reconnectTimer;

  final _events = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _events.stream;

  final _status = StreamController<RealtimeConnStatus>.broadcast();
  Stream<RealtimeConnStatus> get status => _status.stream;

  RealtimeConnStatus _current = RealtimeConnStatus.disconnected;
  RealtimeConnStatus get currentStatus => _current;

  bool _disposed = false;
  bool _connecting = false;

  void _setStatus(RealtimeConnStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> connect() async {
    if (_disposed) return;
    if (_connecting) return;

    _connecting = true;
    _setStatus(_ws == null ? RealtimeConnStatus.connecting : RealtimeConnStatus.reconnecting);

    try {
      final token = await TokenStore.getAccessToken();
      if (token == null || token.isEmpty) {
        _setStatus(RealtimeConnStatus.disconnected);
        _connecting = false;
        return;
      }

      // IMPORTANT: adjust if your ws base differs
      // Example: AppConfig.wsBase = "ws://192.168.8.191:4000"
      final uri = Uri.parse("${AppConfig.wsBase}/ws/realtime?token=$token");

      _ws = await WebSocket.connect(uri.toString());

      _ws!.listen(
        (data) {
          try {
            final raw = jsonDecode(data as String) as Map<String, dynamic>;
            final ev = RealtimeEvent.fromJson(raw);
            _events.add(ev);

            if (ev.isConnected) {
              _setStatus(RealtimeConnStatus.connected);
            }
          } catch (_) {
            // ignore malformed messages
          }
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handleDisconnect() {
    if (_disposed) return;
    _setStatus(RealtimeConnStatus.disconnected);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      connect();
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _ws?.close();
    } catch (_) {}

    _ws = null;
    if (!_disposed) _setStatus(RealtimeConnStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _events.close();
    _status.close();
  }
}
