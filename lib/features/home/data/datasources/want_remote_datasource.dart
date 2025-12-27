import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/auth_headers.dart';

abstract class WantRemoteDataSource {
  Future<Map<String, dynamic>> createWant({
    required String itemName,
    required double price,
    String? notes,
    int? remindAfterHours,
  });

  Future<List<Map<String, dynamic>>> getWants();
}

class WantRemoteDataSourceImpl implements WantRemoteDataSource {
  final http.Client client;

  WantRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> createWant({
    required String itemName,
    required double price,
    String? notes,
    int? remindAfterHours,
  }) async {
    final uri = Uri.parse(ApiEndpoints.wants); // MUST be /api/wants

    final headers = await AuthHeaders.json();

    final res = await client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'itemName': itemName,
        'price': price,
        'notes': notes,
        'remindAfterHours': remindAfterHours,
      }),
    );

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return body;
      throw Failure('Invalid response format (want).');
    }

    throw Failure(
      (body is Map && body['message'] != null)
          ? body['message'].toString()
          : 'Failed to create want (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getWants() async {
    final uri = Uri.parse(ApiEndpoints.wants);

    final headers = await AuthHeaders.json();

    final res = await client.get(uri, headers: headers);

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) {
        return body.whereType<Map<String, dynamic>>().toList();
      }
      throw Failure('Invalid response format (wants list).');
    }

    throw Failure(
      (body is Map && body['message'] != null)
          ? body['message'].toString()
          : 'Failed to fetch wants (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }

  dynamic _safeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}
