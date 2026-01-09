import 'dart:math';

import 'data/datasources/alerts_local_datasource.dart';
import 'data/models/alert_model.dart';
import '../../core/notifications/local_notifications_service.dart';

class AlertsService {
  AlertsService._();
  static final AlertsService instance = AlertsService._();

  final _local = AlertsLocalDataSource();

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  int _stableInt(String s) {
    int hash = 0;
    for (final c in s.codeUnits) {
      hash = 0x1fffffff & (hash + c);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return max(1, hash);
  }

  Future<void> logAction({
    required String title,
    required String message,
    String? wantId,
  }) async {
    await _local.add(
      AlertModel(
        id: _id(),
        type: AlertType.action,
        title: title,
        message: message,
        createdAt: DateTime.now(),
        scheduledFor: null,
        wantId: wantId,
        reminderPending: false,
        notificationId: null,
      ),
    );
  }

  Future<void> resolveReminder(String alertId) async {
    await _local.markReminderResolvedByAlertId(alertId);
  }

  Future<void> scheduleReminderForWant({
    required String wantId,
    required Duration after,
    required String wantName,
    required double wantPrice,
  }) async {
    final now = DateTime.now();
    final scheduledFor = now.add(after);

    final alertId = _id();
    final notificationId = _stableInt(alertId);

    final title = 'IT’S TIME!';
    final msg = 'Here is your reminder for "$wantName"';

    // 1) Save in-app reminder alert
    await _local.add(
      AlertModel(
        id: alertId,
        type: AlertType.reminder,
        title: title,
        message: msg,
        createdAt: now,
        scheduledFor: scheduledFor,
        wantId: wantId,
        reminderPending: true,
        notificationId: notificationId,
      ),
    );

    // 2) Schedule phone notification
    await LocalNotificationsService.scheduleWantReminder(
      notificationId: notificationId,
      scheduledFor: scheduledFor,
      wantId: wantId,
      wantName: wantName,
      wantPrice: wantPrice,
      waited: after,
      alertId: alertId,
    );

    // 3) If app is OPEN, show popup automatically when time hits
    LocalNotificationsService.scheduleInAppPopup(
      after: after,
      wantId: wantId,
      wantName: wantName,
      wantPrice: wantPrice,
      waited: after,
      alertId: alertId,
      notificationId: notificationId,
    );
  }
}
