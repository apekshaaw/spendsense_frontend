import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../models/user_model.dart'; // <- adjust path if your folder is `model` not `models`

/// Contract for remote auth operations
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

/// Implementation using REST API + http package
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
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      throw Failure('Cannot reach server. Check your internet or backend.');
    } on TimeoutException {
      throw Failure('Request timed out. Please try again.');
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
              'confirmPassword': confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      throw Failure('Cannot reach server. Check your internet or backend.');
    } on TimeoutException {
      throw Failure('Request timed out. Please try again.');
    }
  }

  UserModel _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final Map<String, dynamic> bodyJson =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (statusCode >= 200 && statusCode < 300) {
      return UserModel.fromJson(bodyJson);
    } else {
      final message = bodyJson['message']?.toString() ??
          'Unexpected error occurred. Code: $statusCode';
      throw Failure(message, statusCode: statusCode);
    }
  }
}
