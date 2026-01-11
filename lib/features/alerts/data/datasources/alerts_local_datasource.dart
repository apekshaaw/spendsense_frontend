import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_model.dart';

class AlertsLocalDataSource {
  static const _key = 'alerts_feed_v1';
  static const _maxItems = 200;

  Future<List<AlertModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = AlertModel.decodeList(raw);

    // newest first
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveAll(List<AlertModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = items.take(_maxItems).toList();
    await prefs.setString(_key, AlertModel.encodeList(trimmed));
  }

  Future<void> add(AlertModel alert) async {
    final list = await getAll();
    final updated = [alert, ...list];
    await saveAll(updated);
  }

  Future<void> markReminderResolvedByAlertId(String alertId) async {
    final list = await getAll();
    final updated = list.map((a) {
      if (a.id == alertId) {
        return a.copyWith(reminderPending: false);
      }
      return a;
    }).toList();
    await saveAll(updated);
  }

  Future<AlertModel?> getNextReminder() async {
    final list = await getAll();
    final now = DateTime.now();

    final pending = list
        .where((a) =>
            a.type == AlertType.reminder &&
            a.reminderPending == true &&
            a.scheduledFor != null &&
            a.scheduledFor!.isAfter(now))
        .toList();

    if (pending.isEmpty) return null;

    pending.sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
    return pending.first;
  }

  /// ✅ Clear everything
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// ✅ Clear only a specific type (Action / Reminder / Progress)
  Future<void> clearByType(AlertType type) async {
    final list = await getAll();
    final filtered = list.where((a) => a.type != type).toList();
    await saveAll(filtered);
  }
}
