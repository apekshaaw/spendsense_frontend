import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spendsense_frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:spendsense_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:spendsense_frontend/features/auth/domain/entities/user_entity.dart';
import 'package:spendsense_frontend/features/auth/domain/usecases/login_usecase.dart';
import '../../../../core/error/failure.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginViewModel extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;

  // You can inject repository/usecase via constructor if you later add service locator
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
      LoginSubmitted event, Emitter<LoginState> emit) async {
    emit(state.copyWith(status: LoginStatus.loading, errorMessage: null));

    try {
      final UserEntity user = await _loginUseCase(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(status: LoginStatus.success, user: user));
    } on Failure catch (f) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: f.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  void _onLoginReset(LoginReset event, Emitter<LoginState> emit) {
    emit(const LoginState(status: LoginStatus.initial));
  }
}
