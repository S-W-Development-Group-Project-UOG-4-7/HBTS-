import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'auth/auth_gate.dart';
import 'state/notification_store.dart';
import 'widgets/in_app_notification_banner.dart';

import 'state/conductor_store.dart';
import 'state/active_trip_store.dart';
import 'services/realtime_ws.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NotificationStore()..refresh(),
        ),

        // ✅ NEW: Conductor Home state
        ChangeNotifierProvider(
          create: (_) => ConductorStore(),
        ),

        // ✅ NEW: Active Trip state (bookings, filters, counters)
        ChangeNotifierProvider(
          create: (_) => ActiveTripStore(),
        ),

        Provider(
          create: (_) => RealtimeWsService(),
          dispose: (_, ws) => ws.dispose(),
        ),
      ],
      child: const HBTSApp(),
    ),
  );
}

class HBTSApp extends StatefulWidget {
  const HBTSApp({super.key});

  @override
  State<HBTSApp> createState() => _HBTSAppState();
}

class _HBTSAppState extends State<HBTSApp> {
  StreamSubscription? _sub;
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;

    final store = context.read<NotificationStore>();

    // ✅ start websocket realtime after first frame
    store.startRealtime();
    store.startPolling(interval: const Duration(seconds: 3));

    // ✅ listen for popup events
    _sub = store.incomingStream.listen((n) {
      if (!mounted) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      InAppNotificationBanner.show(
        ctx,
        title: n.title,
        message: n.message,
        onTap: () => Navigator.pushNamed(ctx, AppRoutes.notifications),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HBTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      onGenerateRoute: AppRoutes.onGenerate,
      home: const AuthGate(),
    );
  }
}
