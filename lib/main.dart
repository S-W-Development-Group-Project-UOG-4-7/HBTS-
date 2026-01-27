import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'auth/auth_gate.dart';
import 'state/notification_store.dart';
import 'widgets/in_app_notification_banner.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NotificationStore()..refresh(),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
