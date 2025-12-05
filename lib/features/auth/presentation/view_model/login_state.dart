import 'package:spendsense_frontend/features/auth/domain/entities/user_entity.dart';
git commit -m "feat(auth): add login screen and bloc logic"
enum LoginStatus { initial, loading, success, failure }

class LoginState {
  final LoginStatus status;
  final UserEntity? user;
  final String? errorMessage;

  const LoginState({
    this.status = LoginStatus.initial,
    this.user,
    this.errorMessage,
  });

  LoginState copyWith({
    LoginStatus? status,
    UserEntity? user,
    String? errorMessage,
  }) {
    return LoginState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}
