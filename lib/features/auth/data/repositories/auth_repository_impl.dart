import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    final userModel = await remoteDataSource.login(
      email: email,
      password: password,
    );
    return userModel; // UserModel extends UserEntity
  }

  @override
  Future<UserEntity> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final userModel = await remoteDataSource.register(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
    return userModel;
  }
}
