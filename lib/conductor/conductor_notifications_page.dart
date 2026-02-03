import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/notification_store.dart';

class ConductorNotificationsPage extends StatelessWidget {
  const ConductorNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotificationStore>();

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: RefreshIndicator(
        onRefresh: () async => store.refresh(),
        child: ListView.builder(
          itemCount: store.items.length,
          itemBuilder: (ctx, i) {
            final n = store.items[i];
            return ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(n.message),
            );
          },
        ),
      ),
    );
  }
}
