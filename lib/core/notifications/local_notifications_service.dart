import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/navigation/app_navigator.dart';
import '../../features/alerts/alerts_service.dart';
import '../../features/home/data/datasources/home_remote_datasource.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'spendsense_reminders';
  static const String channelName = 'SpendSense Reminders';
  static const String channelDesc = 'Reminder notifications for wants';

  static const String actionSkipped = 'ACTION_SKIPPED';
  static const String actionPurchased = 'ACTION_PURCHASED';

  // Used to pass popup request from background -> app open
  static const String _pendingPopupKey = 'pending_reminder_popup_payload';

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    // ✅ Works whether flutter_timezone returns String OR TimezoneInfo
    try {
      final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
      final String tzName = (tzInfo is String) ? tzInfo : tzInfo.toString();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap, // foreground / main isolate
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    // Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Call this once after runApp (post-frame) to show popup if user tapped notif while app was closed.
  static Future<void> showPendingPopupIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPopupKey);
    if (raw == null || raw.isEmpty) return;

    await prefs.remove(_pendingPopupKey);

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      await _showReminderPopup(payload);
    } catch (_) {}
  }

  /// Schedules the phone notification
  static Future<void> scheduleWantReminder({
    required int notificationId,
    required DateTime scheduledFor,
    required String wantId,
    required String wantName,
    required double wantPrice,
    required Duration waited,
    required String alertId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionSkipped,
          'Skip',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          actionPurchased,
          'Buy',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ✅ include everything needed for the popup
    final payload = jsonEncode({
      'wantId': wantId,
      'alertId': alertId,
      'notificationId': notificationId,
      'name': wantName,
      'price': wantPrice,
      'waitedSeconds': waited.inSeconds,
    });

    final tzTime = tz.TZDateTime.from(scheduledFor, tz.local);

    await _plugin.zonedSchedule(
      notificationId,
      'IT’S TIME!',
      'Reminder for "$wantName"',
      tzTime,
      details,
      payload: payload,

      // ✅ avoids exact_alarms_not_permitted
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// ✅ If app is OPEN, show the popup automatically when the time hits.
  /// This does NOT schedule another notification; it only shows UI if app is alive.
  static void scheduleInAppPopup({
    required Duration after,
    required String wantId,
    required String wantName,
    required double wantPrice,
    required Duration waited,
    required String alertId,
    required int notificationId,
  }) {
    Future.delayed(after, () async {
      // app might be closed; if so nothing happens (that’s fine, phone notif will cover)
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;

final ctx = appNavigatorKey.currentState?.overlay?.context;
if (ctx == null) return;


      await _showReminderPopup({
        'wantId': wantId,
        'alertId': alertId,
        'notificationId': notificationId,
        'name': wantName,
        'price': wantPrice,
        'waitedSeconds': waited.inSeconds,
      });
    });
  }

  static Future<void> cancel(int notificationId) => _plugin.cancel(notificationId);

  // ---------------- TAP HANDLERS ----------------

  static Future<void> _onTap(NotificationResponse res) async {
    await _handleTapOrAction(res, fromBackground: false);
  }

  @pragma('vm:entry-point')
  static Future<void> _onTapBackground(NotificationResponse res) async {
    await _handleTapOrAction(res, fromBackground: true);
  }

  static Future<void> _handleTapOrAction(
    NotificationResponse res, {
    required bool fromBackground,
  }) async {
    final raw = res.payload;
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final wantId = (payload['wantId'] ?? '').toString();
    final alertId = (payload['alertId'] ?? '').toString();
    if (wantId.isEmpty) return;

    // ✅ If user pressed notification ACTION buttons
    if (res.actionId == actionSkipped || res.actionId == actionPurchased) {
      final status = (res.actionId == actionSkipped) ? 'skipped' : 'purchased';

      final ds = HomeRemoteDataSource();
      await ds.updateWantStatus(wantId, status);

      await AlertsService.instance.logAction(
        title: status == 'skipped' ? 'Temptation skipped ✅' : 'Temptation purchased 🛒',
        message: status == 'skipped'
            ? 'Nice — you chose discipline.'
            : 'It happens — reset and go again.',
        wantId: wantId,
      );

      if (alertId.isNotEmpty) {
        await AlertsService.instance.resolveReminder(alertId);
      }
      return;
    }

    // ✅ Otherwise: user tapped the notification itself -> show popup
    if (fromBackground) {
      // Can't show UI from background isolate — store and show on app start
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPopupKey, raw);
      return;
    }

    await _showReminderPopup(payload);
  }

  // ---------------- POPUP UI ----------------

  static Future<void> _showReminderPopup(Map<String, dynamic> payload) async {
    final ctx = appNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;

    final wantId = (payload['wantId'] ?? '').toString();
    final alertId = (payload['alertId'] ?? '').toString();
    final wantName = (payload['name'] ?? 'your latest temptation').toString();

    final priceRaw = payload['price'];
    final double price = (priceRaw is num) ? priceRaw.toDouble() : double.tryParse('$priceRaw') ?? 0;

    final waitedSecondsRaw = payload['waitedSeconds'];
    final waitedSeconds = (waitedSecondsRaw is num)
        ? waitedSecondsRaw.toInt()
        : int.tryParse('$waitedSecondsRaw') ?? 0;

    final waited = Duration(seconds: waitedSeconds);

    final notifIdRaw = payload['notificationId'];
    final int? notificationId =
        (notifIdRaw is num) ? notifIdRaw.toInt() : int.tryParse('$notifIdRaw');

    final waitedText = _formatWaited(waited);
    final saveText = price > 0 ? 'Save Rs${price.toStringAsFixed(0)}' : 'Save';

    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _ReminderDialog(
        wantName: wantName,
        waitedText: waitedText,
        saveText: saveText,
        onSkip: () async {
          await _applyStatusAndClose(
            context: ctx,
            wantId: wantId,
            alertId: alertId,
            notificationId: notificationId,
            status: 'skipped',
          );
        },
        onBuy: () async {
          await _applyStatusAndClose(
            context: ctx,
            wantId: wantId,
            alertId: alertId,
            notificationId: notificationId,
            status: 'purchased',
          );
        },
        onSnooze: () async {
          // Snooze = dismiss only, no reschedule
          if (alertId.isNotEmpty) {
            await AlertsService.instance.resolveReminder(alertId);
          }
          await AlertsService.instance.logAction(
            title: 'Snoozed 😴',
            message: 'You snoozed "$wantName".',
            wantId: wantId,
          );

          if (notificationId != null) {
            // safe: cancels if still scheduled somewhere
            await cancel(notificationId);
          }

          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  static Future<void> _applyStatusAndClose({
    required BuildContext context,
    required String wantId,
    required String alertId,
    required int? notificationId,
    required String status,
  }) async {
    final ds = HomeRemoteDataSource();
    await ds.updateWantStatus(wantId, status);

    await AlertsService.instance.logAction(
      title: status == 'skipped' ? 'Temptation skipped ✅' : 'Temptation purchased 🛒',
      message: status == 'skipped'
          ? 'Nice — you chose discipline.'
          : 'It happens — reset and go again.',
      wantId: wantId,
    );

    if (alertId.isNotEmpty) {
      await AlertsService.instance.resolveReminder(alertId);
    }

    if (notificationId != null) {
      await cancel(notificationId);
    }

    Navigator.of(context).pop();
  }

  static String _formatWaited(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    if (d.inHours < 24) return '${d.inHours} hours';
    if (d.inDays < 7) return '${d.inDays} days';
    final w = (d.inDays / 7).round();
    return '$w week${w == 1 ? '' : 's'}';
  }
}

// ---------- UI WIDGET (matches your prototype style) ----------

class _ReminderDialog extends StatelessWidget {
  final String wantName;
  final String waitedText;
  final String saveText;
  final VoidCallback onSkip;
  final VoidCallback onBuy;
  final VoidCallback onSnooze;

  const _ReminderDialog({
    required this.wantName,
    required this.waitedText,
    required this.saveText,
    required this.onSkip,
    required this.onBuy,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "IT’S TIME!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF123A63),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "You waited $waitedText.",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Here is your reminder for\n“$wantName”',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSkip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF123A63),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Skip\n($saveText)",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onBuy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Buy\n(Impulse)",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSnooze,
              icon: const Icon(Icons.alarm, size: 18),
              label: const Text("Snooze"),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
