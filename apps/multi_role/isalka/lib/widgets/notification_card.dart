import 'package:flutter/material.dart';

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    final priority = notification['priority'] ?? 'normal';
    final type = notification['type'] ?? 'system';

    Color iconColor = Colors.blue;
    IconData icon = Icons.notifications;

    switch (type) {
      case 'payment':
        icon = Icons.payment;
        iconColor = Colors.green;
        break;
      case 'booking':
        icon = Icons.receipt_long;
        iconColor = Colors.blue;
        break;
      case 'safety':
        icon = Icons.warning;
        iconColor = Colors.red;
        break;
    }

    return Card(
      elevation: 2,
      color: priority == 'high'
          ? Colors.red.shade50
          : Colors.white,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(notification['message']),
        trailing: !isRead
            ? const Icon(Icons.circle, color: Colors.red, size: 10)
            : null,
        onTap: onTap,
      ),
    );
  }
}
