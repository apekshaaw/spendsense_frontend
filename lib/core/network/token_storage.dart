import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _primaryKey = 'token';
  static const _legacyKeys = ['authToken', 'accessToken'];

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();

    final primary = prefs.getString(_primaryKey);
    if (primary != null && primary.isNotEmpty) return primary;

    for (final k in _legacyKeys) {
      final t = prefs.getString(k);
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  static Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_primaryKey, token);

    // keep old keys synced so older code never breaks
    for (final k in _legacyKeys) {
      await prefs.setString(k, token);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_primaryKey);
    for (final k in _legacyKeys) {
      await prefs.remove(k);
    }
  }
}
