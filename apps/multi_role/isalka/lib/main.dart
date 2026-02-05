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
import 'services/token_store.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NotificationStore()..refresh(),
        ),

        // NEW: Conductor Home state
        ChangeNotifierProvider(
          create: (_) => ConductorStore(),
        ),

        // NEW: Active Trip state (bookings, filters, counters)
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<NotificationStore>();

      // ✅ start websocket realtime after first frame
      store.startRealtime();
      store.startPolling(interval: const Duration(seconds: 3));

      // ✅ listen for popup events
      _sub = store.incomingStream.listen((n) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;

        InAppNotificationBanner.show(
          ctx,
          title: n.title,
          message: n.message,
          onTap: () => Navigator.pushNamed(ctx, AppRoutes.notifications),
        );
      });

      final ws = context.read<RealtimeWsService>();
      final activeTripStore = context.read<ActiveTripStore>();

      final role = await TokenStore.getRole();
      if (role == "conductor") {
        await ws.connect();

        ws.events.listen((ev) async {
          if (ev.isTripStarted) {
            // refresh so active trip card appears + bookings load
            await activeTripStore.loadActiveTripAndBookings();
            return;
          }

          if (ev.isTripEnded) {
            activeTripStore.requestTripClosedDialog(reason: "ended");
            return;
          }

          if (ev.isTripCancelled) {
            activeTripStore.requestTripClosedDialog(reason: "cancelled");
            return;
          }
        });
      }
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
