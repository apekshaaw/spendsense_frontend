import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile_model.dart';

class ProfileLocalCache {
  static const _key = 'cached_profile';

  static Future<void> save(ProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  static Future<ProfileModel?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ProfileModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
