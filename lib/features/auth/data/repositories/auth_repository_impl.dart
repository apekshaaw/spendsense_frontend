// lib/features/auth/data/repositories/auth_repository_impl.dart

import 'package:spendsense_frontend/core/error/failure.dart';
import 'package:spendsense_frontend/features/auth/domain/entities/user_entity.dart';
import 'package:spendsense_frontend/features/auth/domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserModel userModel = await remoteDataSource.login(
        email: email,
        password: password,
      );

      // If UserModel already extends UserEntity, you can just return userModel.
      return userModel; // or userModel.toEntity();
    } on Failure {
      // Just bubble up our Failure
      rethrow;
    } catch (e) {
      // Anything else → wrap into Failure so ViewModel can handle it
      throw Failure('Login failed: $e');
    }
  }

  @override
  Future<UserEntity> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final UserModel userModel = await remoteDataSource.register(
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );

      return userModel; // or userModel.toEntity();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Registration failed: $e');
    }
  }
}
