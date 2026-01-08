import 'dart:convert';
import 'package:http/http.dart' as http;

import '../error/failure.dart';

class ApiClient {
  const ApiClient();

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final res = await http.get(Uri.parse(url), headers: headers);
      return _handleResponse(res);
    } catch (e) {
      throw Failure("Network error: $e");
    }
  }

  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      return _handleResponse(res);
    } catch (e) {
      throw Failure("Network error: $e");
    }
  }

  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final res = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      return _handleResponse(res);
    } catch (e) {
      throw Failure("Network error: $e");
    }
  }

  Future<Map<String, dynamic>> patch(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final res = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      return _handleResponse(res);
    } catch (e) {
      throw Failure("Network error: $e");
    }
  }

  Map<String, dynamic> _handleResponse(http.Response res) {
    final status = res.statusCode;
    final raw = (res.body).trim();

    // ✅ If we got HTML instead of JSON, don't jsonDecode
    if (raw.startsWith('<!DOCTYPE') || raw.startsWith('<html') || raw.startsWith('<')) {
      final preview = raw.length > 140 ? raw.substring(0, 140) : raw;
      throw Failure(
        "API returned HTML (not JSON). Status $status.\n"
        "This usually means wrong endpoint or backend not running.\n"
        "Response preview: $preview",
      );
    }

    dynamic decoded;
    try {
      decoded = raw.isEmpty ? {} : jsonDecode(raw);
    } catch (e) {
      // ✅ Handle garbage/non-json safely
      throw Failure(
        "Invalid JSON response. Status $status.\n"
        "Body preview: ${raw.length > 140 ? raw.substring(0, 140) : raw}",
      );
    }

    if (status >= 200 && status < 300) {
      if (decoded is Map<String, dynamic>) return decoded;

      // If backend returns list/string/etc, wrap it so app won't crash
      return {"data": decoded};
    }

    // Error response
    String message = "Request failed ($status)";
    if (decoded is Map && decoded["message"] != null) {
      message = decoded["message"].toString();
    } else if (raw.isNotEmpty) {
      message = raw;
    }

    throw Failure(message);
  }
}
