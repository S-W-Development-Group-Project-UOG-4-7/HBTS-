import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/notification_api.dart';
import '../services/notification_ws.dart';

class NotificationStore extends ChangeNotifier {
  final List<PassengerNotification> _items = [];
  bool _loading = false;
  bool _firstLoadDone = false;
  Timer? _pollTimer;

  // ✅ WebSocket
  final NotificationWS _ws = NotificationWS();

  // ✅ optional fallback polling (only if WS drops)
  Timer? _fallbackTimer;

  // ✅ stream for UI popups
  final StreamController<PassengerNotification> _incoming =
      StreamController<PassengerNotification>.broadcast();
  Stream<PassengerNotification> get incomingStream => _incoming.stream;

  // ✅ prevent duplicate popups
  final Set<int> _seenIds = {};

  List<PassengerNotification> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  int _typePriority(PassengerNotification n) {
    final t = n.type.toUpperCase();
    final c = n.category.toLowerCase();

    if (t.contains("DELAY") || t.contains("CANCEL") || t.contains("STATUS") || c == "system") return 1;
    if (t.contains("BOOK") || c == "booking") return 2;
    if (t.contains("PAY") || c == "payment") return 3;
    return 4;
  }

  void _sort() {
    _items.sort((a, b) {
      if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
      final pa = _typePriority(a);
      final pb = _typePriority(b);
      if (pa != pb) return pa.compareTo(pb);
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    final oldIds = _items.map((e) => e.id).toSet();

    try {
      final raw = await NotificationApi.fetchNotifications();

      final parsed = <PassengerNotification>[];
      for (final e in raw) {
        if (e is Map) {
          parsed.add(
            PassengerNotification.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }

      _items
        ..clear()
        ..addAll(parsed);

      _sort();

      // Trigger popup for NEW unread notifications (after first load)
      if (_firstLoadDone) {
        final newUnread =
            parsed.where((n) => !oldIds.contains(n.id) && !n.isRead).toList();

        if (newUnread.isNotEmpty) {
          final n = newUnread.first;

          // prevent duplicates
          if (_seenIds.add(n.id)) {
            _incoming.add(n);
          }
        }
      } else {
        // first load: don't popup historical notifications
        _firstLoadDone = true;
      }

      // always keep seenIds updated
      for (final n in parsed) {
        _seenIds.add(n.id);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ✅ Start realtime
  Future<void> startRealtime() async {
    // stop fallback polling
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    // connect ws
    await _ws.connect(
      onNotification: (n) async {
        // popup only if brand-new
        final isNew = !_seenIds.contains(n.id);
        _seenIds.add(n.id);

        // merge at top
        _upsert(n);

        if (isNew && !n.isRead) {
          _incoming.add(n);
        }

        notifyListeners();
      },
      onDisconnected: () {
        // fallback to polling if ws drops
        startFallbackPolling();
        Future.delayed(const Duration(seconds: 2), () => startRealtime());
      },
    );
  }

  // ✅ fallback polling (only used when ws disconnects)
  void startFallbackPolling({Duration interval = const Duration(seconds: 12)}) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(interval, (_) async {
      try {
        await refresh();
      } catch (_) {}
    });
  }

  void startPolling({Duration interval = const Duration(seconds: 3)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        await refresh();
      } catch (_) {}
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void stopRealtime() {
    _ws.disconnect();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _upsert(PassengerNotification n) {
    final idx = _items.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      _items[idx] = n;
    } else {
      _items.insert(0, n);
    }
    _sort();
  }

  Future<void> markRead(int id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    if (_items[idx].isRead) return;

    _items[idx] = _items[idx].copyWith(isRead: true);
    _sort();
    notifyListeners();

    try {
      await NotificationApi.markAsRead(id.toString());
    } catch (_) {
      _items[idx] = _items[idx].copyWith(isRead: false);
      _sort();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopRealtime();
    stopPolling();
    _incoming.close();
    super.dispose();
  }
}
