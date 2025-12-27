import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsense_frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:spendsense_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:spendsense_frontend/features/auth/domain/entities/user_entity.dart';
import 'package:spendsense_frontend/features/auth/domain/usecases/login_usecase.dart';

import '../../../../core/error/failure.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginViewModel extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;

  LoginViewModel({LoginUseCase? loginUseCase})
      : _loginUseCase = loginUseCase ??
            LoginUseCase(
              AuthRepositoryImpl(
                remoteDataSource: AuthRemoteDataSourceImpl(),
              ),
            ),
        super(const LoginState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginReset>(_onLoginReset);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(status: LoginStatus.loading, errorMessage: null));

    try {
      final UserEntity user = await _loginUseCase(
        email: event.email,
        password: event.password,
      );

      // ✅ DO NOT save token here.
      // AuthRemoteDataSource already saves it.
      // Saving here was overwriting the real token with empty user.token.

      // ✅ quick debug: confirm token exists in prefs after login
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('token');
      // ignore: avoid_print
      print("✅ TOKEN IN PREFS AFTER LOGIN: $saved");

      emit(state.copyWith(status: LoginStatus.success, user: user));
    } on Failure catch (f) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: f.message,
        ),
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('LoginViewModel error: $e');
      // ignore: avoid_print
      print(stack);

      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onLoginReset(LoginReset event, Emitter<LoginState> emit) {
    emit(const LoginState(status: LoginStatus.initial));
  }
}
