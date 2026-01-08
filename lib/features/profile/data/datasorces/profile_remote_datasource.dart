import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getMe();
  Future<ProfileModel> updateMe({
    required String name,
    required String email,
    required String phone,
    required bool darkMode,
    required String avatarUrl,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('authToken') ??
        prefs.getString('accessToken');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  ProfileModel _parseUser(dynamic data) {
    // backend returns user directly (your controller: res.json(user))
    final userJson =
        (data is Map && data['user'] != null) ? data['user'] : data;

    return ProfileModel.fromJson(Map<String, dynamic>.from(userJson));
  }

  @override
  Future<ProfileModel> getMe() async {
    final token = await _getAuthToken();
    if (token == null || token.isEmpty) {
      throw Failure('Not authorized, no token. Please log in again.');
    }

    final res = await http.get(
      Uri.parse(ApiEndpoints.profile),
      headers: _headers(token),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return _parseUser(data);
    }

    // if backend returns HTML or something unexpected
    if (res.body.startsWith('<!DOCTYPE') || res.body.startsWith('<html')) {
      throw Failure('Wrong endpoint or backend not running. (${res.statusCode})');
    }

    try {
      final body = jsonDecode(res.body);
      throw Failure(body['message']?.toString() ?? 'Failed to fetch profile');
    } catch (_) {
      throw Failure('Failed to fetch profile (${res.statusCode})');
    }
  }

  @override
  Future<ProfileModel> updateMe({
    required String name,
    required String email,
    required String phone,
    required bool darkMode,
    required String avatarUrl,
  }) async {
    final token = await _getAuthToken();
    if (token == null || token.isEmpty) {
      throw Failure('Not authorized, no token. Please log in again.');
    }

    final res = await http.put(
      Uri.parse(ApiEndpoints.updateProfile),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'darkMode': darkMode,
        'avatarUrl': avatarUrl, // base64 string
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return _parseUser(data);
    }

    if (res.body.startsWith('<!DOCTYPE') || res.body.startsWith('<html')) {
      throw Failure('Wrong endpoint or backend not running. (${res.statusCode})');
    }

    try {
      final body = jsonDecode(res.body);
      throw Failure(body['message']?.toString() ?? 'Failed to update profile');
    } catch (_) {
      throw Failure('Failed to update profile (${res.statusCode})');
    }
  }
}
