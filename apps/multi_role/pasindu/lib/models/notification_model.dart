import 'dart:convert';

enum NotificationPriority {
  low,
  normal,
  high,
}

class PassengerNotification {
  final int id;
  final String type;
  final String category;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final NotificationPriority priority;

  PassengerNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    required this.createdAt,
    required this.priority,
  });

  PassengerNotification copyWith({
    bool? isRead,
  }) {
    return PassengerNotification(
      id: id,
      type: type,
      category: category,
      title: title,
      message: message,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      priority: priority,
    );
  }

  static PassengerNotification fromJson(Map<String, dynamic> json) {
    final rawData = json["data"];
    Map<String, dynamic> parsedData = {};

    if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    } else if (rawData is String && rawData.isNotEmpty) {
      try {
        parsedData = Map<String, dynamic>.from(jsonDecode(rawData));
      } catch (_) {
        parsedData = {};
      }
    }

    final category = (json["category"] ?? "").toString();
    final type = (json["type"] ?? "").toString();
    final priority = _priorityFrom(parsedData, category, type);
    final rawId = json["notification_id"] ?? json["id"] ?? json["notificationId"];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0;

    return PassengerNotification(
      id: id,
      type: type,
      category: category,
      title: (json["title"] ?? "").toString(),
      message: (json["message"] ?? "").toString(),
      data: parsedData,
      isRead: json["is_read"] == true,
      createdAt: DateTime.tryParse((json["created_at"] ?? "").toString()) ??
          DateTime.now(),
      priority: priority,
    );
  }

  static NotificationPriority _priorityFrom(
    Map<String, dynamic> data,
    String category,
    String type,
  ) {
    final raw = (data["priority"] ?? "").toString().toLowerCase();
    if (raw == "high") return NotificationPriority.high;
    if (raw == "normal") return NotificationPriority.normal;
    if (raw == "low") return NotificationPriority.low;

    if (category == "system") return NotificationPriority.high;
    if (category == "payment") return NotificationPriority.normal;
    if (type.contains("DELAY") || type.contains("CANCEL")) {
      return NotificationPriority.high;
    }
    return NotificationPriority.low;
  }
}
