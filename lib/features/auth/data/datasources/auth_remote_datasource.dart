import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/token_storage.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(ApiEndpoints.login);

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final statusCode = response.statusCode;

      // ignore: avoid_print
      print('LOGIN status: $statusCode');
      // ignore: avoid_print
      print('LOGIN body: ${response.body}');

      final Map<String, dynamic> bodyJson =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (statusCode >= 200 && statusCode < 300) {
        final String? token = _extractToken(bodyJson);

        if (token == null || token.isEmpty) {
          throw Failure('Login success but token missing from response.');
        }

        // ✅ write token in a consistent way for the whole app
        await TokenStorage.write(token);

        // ignore: avoid_print
        print('✅ Saved token (LOGIN): $token');

        final dynamic userDataRaw = bodyJson['user'] ?? bodyJson;

        if (userDataRaw is! Map<String, dynamic>) {
          throw Failure('Invalid response format from server (user missing).');
        }

        final userData = <String, dynamic>{
          ...userDataRaw,
          'token': token,
        };

        return UserModel.fromJson(userData);
      } else {
        final message = bodyJson['message']?.toString() ??
            'Unexpected error occurred. Code: $statusCode';
        throw Failure(message, statusCode: statusCode);
      }
    } on SocketException {
      throw Failure('Cannot reach server. Check your internet or backend.');
    } on TimeoutException {
      throw Failure('Request timed out. Please try again.');
    } on Failure {
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('LOGIN parse error: $e');
      throw Failure('Failed to parse server response.');
    }
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final uri = Uri.parse(ApiEndpoints.register);

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'confirmPassword': confirmPassword, // backend ignores (fine)
            }),
          )
          .timeout(const Duration(seconds: 10));

      final statusCode = response.statusCode;

      // ignore: avoid_print
      print('REGISTER status: $statusCode');
      // ignore: avoid_print
      print('REGISTER body: ${response.body}');

      final Map<String, dynamic> bodyJson =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (statusCode >= 200 && statusCode < 300) {
        final String? token = _extractToken(bodyJson);

        if (token == null || token.isEmpty) {
          throw Failure('Signup success but token missing from response.');
        }

        // ✅ write token in a consistent way for the whole app
        await TokenStorage.write(token);

        // ignore: avoid_print
        print('✅ Saved token (REGISTER): $token');

        final dynamic userDataRaw = bodyJson['user'] ?? bodyJson;

        if (userDataRaw is! Map<String, dynamic>) {
          throw Failure('Invalid response format from server (user missing).');
        }

        final userData = <String, dynamic>{
          ...userDataRaw,
          'token': token,
        };

        return UserModel.fromJson(userData);
      } else {
        final message = bodyJson['message']?.toString() ??
            'Unexpected error occurred. Code: $statusCode';
        throw Failure(message, statusCode: statusCode);
      }
    } on SocketException {
      throw Failure('Cannot reach server. Check your internet or backend.');
    } on TimeoutException {
      throw Failure('Request timed out. Please try again.');
    } on Failure {
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('REGISTER parse error: $e');
      throw Failure('Failed to parse server response.');
    }
  }

  String? _extractToken(Map<String, dynamic> bodyJson) {
    return bodyJson['token'] as String? ??
        bodyJson['accessToken'] as String? ??
        bodyJson['jwt'] as String?;
  }
}
