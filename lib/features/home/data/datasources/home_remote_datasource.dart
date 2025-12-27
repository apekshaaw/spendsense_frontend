import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/auth_headers.dart';
import '../models/goal_model.dart';
import '../models/need_model.dart';
import '../models/want_model.dart';

class HomeRemoteDataSource {
  final http.Client client;

  HomeRemoteDataSource({http.Client? client}) : client = client ?? http.Client();

  Future<GoalModel?> getMyGoal() async {
    final headers = await AuthHeaders.json();
    final res = await client.get(
      Uri.parse('${ApiEndpoints.baseUrl}/api/goals/me'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      return GoalModel.fromJson(jsonDecode(res.body));
    }

    if (res.statusCode == 404) {
      // no goal set yet - return null (not an error)
      return null;
    }

    throw Failure(_extractMessage(res.body, fallback: 'Failed to fetch goal.'));
  }

  Future<List<WantModel>> getWants() async {
    final headers = await AuthHeaders.json();
    final res = await client.get(
      Uri.parse('${ApiEndpoints.baseUrl}/api/wants'),
      headers: headers,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => WantModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw Failure(_extractMessage(res.body, fallback: 'Failed to fetch wants.'));
  }

  Future<List<NeedModel>> getNeeds() async {
    final headers = await AuthHeaders.json();
    final res = await client.get(
      Uri.parse('${ApiEndpoints.baseUrl}/api/needs'),
      headers: headers,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => NeedModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw Failure(_extractMessage(res.body, fallback: 'Failed to fetch needs.'));
  }

  Future<void> deleteNeed(String id) async {
    final headers = await AuthHeaders.json();
    final res = await client.delete(
      Uri.parse('${ApiEndpoints.baseUrl}/api/needs/$id'),
      headers: headers,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Failure(_extractMessage(res.body, fallback: 'Failed to delete need.'));
  }

  Future<void> deleteWant(String id) async {
    final headers = await AuthHeaders.json();
    final res = await client.delete(
      Uri.parse('${ApiEndpoints.baseUrl}/api/wants/$id'),
      headers: headers,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Failure(_extractMessage(res.body, fallback: 'Failed to delete want.'));
  }

  Future<WantModel> updateWantStatus(String id, String status) async {
    final headers = await AuthHeaders.json();
    final res = await client.patch(
      Uri.parse('${ApiEndpoints.baseUrl}/api/wants/$id/status'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return WantModel.fromJson(jsonDecode(res.body));
    }

    throw Failure(_extractMessage(res.body, fallback: 'Failed to update status.'));
  }

  String _extractMessage(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}
