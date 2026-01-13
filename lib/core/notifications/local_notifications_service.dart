// lib/core/notifications/local_notifications_service.dart
import 'dart:convert';
import 'dart:math';

import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lottie/lottie.dart';
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

  /// Stores UI actions when we can't show dialogs (background isolate)
  static const String _pendingUiKey = 'pending_ui_popup_payload_v1';

  /// Simple streak keys
  static const String _streakCountKey = 'streak_count_v1';
  static const String _streakLastDayKey = 'streak_last_day_v1';

  /// ✅ Your .lottie assets
  static const String _skipAnimAsset = 'assets/anim/thumbs_up.lottie';
  static const String _buyAnimAsset = 'assets/anim/sad_tear.lottie';

  static final Random _rng = Random();
  static int _lastSkipMsgIndex = -1;
  static int _lastBuyMsgIndex = -1;

  static Future<void> init() async {
    tzdata.initializeTimeZones();

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
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    // Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Call once after runApp (post-frame)
  static Future<void> showPendingPopupIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUiKey);
    if (raw == null || raw.isEmpty) return;

    await prefs.remove(_pendingUiKey);

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final uiType = (payload['uiType'] ?? 'reminder').toString();

      if (uiType == 'result') {
        final outcome = (payload['outcome'] ?? '').toString();
        await _showResultPopupFromPayload(outcome, payload);
      } else {
        await _showReminderPopup(payload);
      }
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
      'uiType': 'reminder',
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// ✅ If app is OPEN, show the popup automatically when the time hits.
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
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != AppLifecycleState.resumed) return;

      final ctx = appNavigatorKey.currentState?.overlay?.context;
      if (ctx == null) return;

      await _showReminderPopup({
        'uiType': 'reminder',
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
        title: status == 'skipped'
            ? 'Temptation skipped ✅'
            : 'Temptation purchased 🛒',
        message: status == 'skipped'
            ? 'Nice — you chose discipline.'
            : 'It happens — reset and go again.',
        wantId: wantId,
      );

      if (alertId.isNotEmpty) {
        await AlertsService.instance.resolveReminder(alertId);
      }

      // Try to show result popup if app is open, otherwise store it
      final prefs = await SharedPreferences.getInstance();

      final resultPayload = <String, dynamic>{
        'uiType': 'result',
        'outcome': status,
        'wantId': wantId,
        'alertId': alertId,
        'notificationId': payload['notificationId'],
        'name': payload['name'],
        'price': payload['price'],
      };

      if (fromBackground) {
        await prefs.setString(_pendingUiKey, jsonEncode(resultPayload));
        return;
      }

      await _showResultPopupFromPayload(status, resultPayload);
      return;
    }

    // ✅ Otherwise: user tapped the notification itself -> show reminder popup
    if (fromBackground) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingUiKey, raw);
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
    final double price = (priceRaw is num)
        ? priceRaw.toDouble()
        : double.tryParse('$priceRaw') ?? 0;

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
            wantName: wantName,
            wantPrice: price,
            showResultPopup: true,
          );
        },
        onBuy: () async {
          await _applyStatusAndClose(
            context: ctx,
            wantId: wantId,
            alertId: alertId,
            notificationId: notificationId,
            status: 'purchased',
            wantName: wantName,
            wantPrice: price,
            showResultPopup: true,
          );
        },
        onSnooze: () async {
          if (alertId.isNotEmpty) {
            await AlertsService.instance.resolveReminder(alertId);
          }
          await AlertsService.instance.logAction(
            title: 'Snoozed 😴',
            message: 'You snoozed "$wantName".',
            wantId: wantId,
          );

          if (notificationId != null) {
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
    required String status, // 'skipped' | 'purchased'
    required String wantName,
    required double wantPrice,
    required bool showResultPopup,
  }) async {
    final ds = HomeRemoteDataSource();
    await ds.updateWantStatus(wantId, status);

    // streak update
    final streak = await _updateStreak(status);

    await AlertsService.instance.logAction(
      title: status == 'skipped'
          ? 'Temptation skipped ✅'
          : 'Temptation purchased 🛒',
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

    // Close the reminder dialog first
    Navigator.of(context).pop();

    if (!showResultPopup) return;

    final state = WidgetsBinding.instance.lifecycleState;
    if (state != AppLifecycleState.resumed) return;

    final ctx = appNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;

    await Future.delayed(const Duration(milliseconds: 120));

    await _showResultPopup(
      ctx,
      outcome: status,
      wantName: wantName,
      wantPrice: wantPrice,
      streak: streak,
    );
  }

  // ---------------- STREAK ----------------

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<int> _updateStreak(String outcome) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());

    int count = prefs.getInt(_streakCountKey) ?? 0;
    final lastDay = prefs.getString(_streakLastDayKey);

    if (outcome == 'purchased') {
      count = 0;
      await prefs.setInt(_streakCountKey, count);
      await prefs.setString(_streakLastDayKey, today);
      return count;
    }

    if (lastDay == today) {
      return count; // already counted today
    }

    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (lastDay == yesterday) {
      count = max(1, count + 1);
    } else {
      count = 1;
    }

    await prefs.setInt(_streakCountKey, count);
    await prefs.setString(_streakLastDayKey, today);
    return count;
  }

  // ---------------- RESULT POPUP (ANIMATED) ----------------

  static Future<void> _showResultPopupFromPayload(
    String outcome,
    Map<String, dynamic> payload,
  ) async {
    final ctx = appNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;

    final wantName = (payload['name'] ?? 'that temptation').toString();
    final priceRaw = payload['price'];
    final double price = (priceRaw is num)
        ? priceRaw.toDouble()
        : double.tryParse('$priceRaw') ?? 0;

    final streak = await _updateStreak(outcome);

    await _showResultPopup(
      ctx,
      outcome: outcome,
      wantName: wantName,
      wantPrice: price,
      streak: streak,
    );
  }

  static Future<void> _showResultPopup(
    BuildContext context, {
    required String outcome, // 'skipped' | 'purchased'
    required String wantName,
    required double wantPrice,
    required int streak,
  }) async {
    final isSkip = outcome == 'skipped';

    final amountText =
        wantPrice > 0 ? 'Rs${wantPrice.toStringAsFixed(0)}' : 'some money';

    final messagesSkip = <String>[
      'Great job! You skipped "$wantName" and saved $amountText.\nStreak: $streak 🔥',
      'Discipline win ✅ You didn’t buy "$wantName".\nSaved $amountText — Streak: $streak',
      'Let’s gooo 😄 You stayed in control.\nSaved $amountText • Streak: $streak',
      'That’s a strong move 💪\nYou skipped "$wantName". Streak is now $streak!',
      'Big W 🏆 Saved $amountText by skipping.\nKeep it up — Streak: $streak',
    ];

    final messagesBuy = <String>[
      'It’s okay — we go again.\nYour streak reset. Tomorrow is a new start 💙',
      'No worries. Awareness is progress.\nStreak dropped, but you’re still learning.',
      'Slip-ups happen.\nReset and come back stronger tomorrow 💪',
      'You bought "$wantName".\nNext time, we pause and breathe. You’ve got this.',
      'Don’t beat yourself up.\nOne moment doesn’t define you — we go again.',
    ];

    final msg = _pickMessage(isSkip ? messagesSkip : messagesBuy, isSkip);

    BuildContext? dialogCtx;

    // Show dialog
    final dialogFuture = showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        dialogCtx = ctx;
        return _ResultDialog(
          title: isSkip ? 'Nice work!' : 'We go again',
          message: msg,
          assetPath: isSkip ? _skipAnimAsset : _buyAnimAsset,
        );
      },
    );

    // Auto close after 2.2s ONLY if dialog is still mounted
    Future.delayed(const Duration(seconds: 7), () {
      if (dialogCtx != null && dialogCtx!.mounted) {
        Navigator.of(dialogCtx!).pop();
      }
    });

    await dialogFuture;
  }

  static String _pickMessage(List<String> list, bool isSkip) {
    if (list.isEmpty) return '';

    int idx = _rng.nextInt(list.length);

    if (isSkip && list.length > 1) {
      if (idx == _lastSkipMsgIndex) idx = (idx + 1) % list.length;
      _lastSkipMsgIndex = idx;
      return list[idx];
    }

    if (!isSkip && list.length > 1) {
      if (idx == _lastBuyMsgIndex) idx = (idx + 1) % list.length;
      _lastBuyMsgIndex = idx;
      return list[idx];
    }

    return list[idx];
  }

  // ---------------- HELPERS ----------------

  static String _formatWaited(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    if (d.inHours < 24) return '${d.inHours} hours';
    if (d.inDays < 7) return '${d.inDays} days';
    final w = (d.inDays / 7).round();
    return '$w week${w == 1 ? '' : 's'}';
  }
}

// ---------- UI WIDGETS ----------

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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final String title;
  final String message;
  final String assetPath;

  const _ResultDialog({
    required this.title,
    required this.message,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Anim(assetPath: assetPath),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Anim extends StatelessWidget {
  final String assetPath;
  const _Anim({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    final isDotLottie = assetPath.toLowerCase().endsWith('.lottie');

    if (isDotLottie) {
      // ✅ Correct way to render .lottie with dotlottie_loader
      return SizedBox(
        height: 120,
        child: DotLottieLoader.fromAsset(
          assetPath,
          frameBuilder: (BuildContext ctx, DotLottie? dotlottie) {
            if (dotlottie == null) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            return Lottie.memory(
              dotlottie.animations.values.single,
              repeat: true,
              fit: BoxFit.contain,
              // If your .lottie contains images, this makes them render too:
              imageProviderFactory: (asset) {
                final bytes = dotlottie.images[asset.fileName];
                if (bytes != null) return MemoryImage(bytes);
                return const AssetImage('assets/images/spendsense_logo_blue.png');
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.emoji_emotions, size: 64),
              ),
            );
          },
          errorBuilder: (ctx, e, s) => const Center(
            child: Icon(Icons.emoji_emotions, size: 64),
          ),
        ),
      );
    }

    // Normal .json lottie
    return SizedBox(
      height: 120,
      child: Lottie.asset(
        assetPath,
        repeat: true,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.emoji_emotions, size: 64),
        ),
      ),
    );
  }
}
