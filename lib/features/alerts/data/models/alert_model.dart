import 'dart:convert';

enum AlertType { action, progress, reminder }

AlertType _typeFrom(String v) {
  switch (v) {
    case 'progress':
      return AlertType.progress;
    case 'reminder':
      return AlertType.reminder;
    case 'action':
    default:
      return AlertType.action;
  }
}

String _typeTo(AlertType t) {
  switch (t) {
    case AlertType.progress:
      return 'progress';
    case AlertType.reminder:
      return 'reminder';
    case AlertType.action:
    default:
      return 'action';
  }
}

class AlertModel {
  final String id;
  final AlertType type;
  final String title;
  final String message;

  final DateTime createdAt;

  /// Only for reminders
  final DateTime? scheduledFor;

  /// Optional: tie to want
  final String? wantId;

  /// reminderPending = true means it's the “Next reminder” candidate
  final bool reminderPending;

  /// Stores notificationId so we can cancel or track it
  final int? notificationId;

  const AlertModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.scheduledFor,
    this.wantId,
    required this.reminderPending,
    this.notificationId,
  });

  AlertModel copyWith({
    AlertType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? scheduledFor,
    String? wantId,
    bool? reminderPending,
    int? notificationId,
  }) {
    return AlertModel(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      wantId: wantId ?? this.wantId,
      reminderPending: reminderPending ?? this.reminderPending,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': _typeTo(type),
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'scheduledFor': scheduledFor?.toIso8601String(),
        'wantId': wantId,
        'reminderPending': reminderPending,
        'notificationId': notificationId,
      };

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] ?? '').toString(),
      type: _typeFrom((json['type'] ?? 'action').toString()),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.tryParse(json['scheduledFor'].toString())
          : null,
      wantId: json['wantId']?.toString(),
      reminderPending: json['reminderPending'] == true,
      notificationId: (json['notificationId'] as num?)?.toInt(),
    );
  }

  static String encodeList(List<AlertModel> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<AlertModel> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
