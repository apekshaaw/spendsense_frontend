import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spendsense_frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:spendsense_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:spendsense_frontend/features/auth/domain/entities/user_entity.dart';
import 'package:spendsense_frontend/features/auth/domain/usecases/register_usecase.dart';
import '../../../../core/error/failure.dart';
import 'register_event.dart';
import 'register_state.dart';

class RegisterViewModel extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUseCase _registerUseCase;

  RegisterViewModel({RegisterUseCase? registerUseCase})
      : _registerUseCase = registerUseCase ??
            RegisterUseCase(
              AuthRepositoryImpl(
                remoteDataSource: AuthRemoteDataSourceImpl(),
              ),
            ),
        super(const RegisterState()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<RegisterReset>(_onRegisterReset);
  }

  Future<void> _onRegisterSubmitted(
      RegisterSubmitted event, Emitter<RegisterState> emit) async {
    emit(state.copyWith(status: RegisterStatus.loading, errorMessage: null));

    try {
      final UserEntity user = await _registerUseCase(
        name: event.name,
        email: event.email,
        password: event.password,
        confirmPassword: event.confirmPassword,
      );
      emit(state.copyWith(status: RegisterStatus.success, user: user));
    } on Failure catch (f) {
      emit(
        state.copyWith(
          status: RegisterStatus.failure,
          errorMessage: f.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RegisterStatus.failure,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  void _onRegisterReset(RegisterReset event, Emitter<RegisterState> emit) {
    emit(const RegisterState(status: RegisterStatus.initial));
  }
}
