import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'splash_event.dart';
import 'splash_state.dart';

class SplashViewModel extends Bloc<SplashEvent, SplashState> {
  SplashViewModel() : super(const SplashState()) {
    on<SplashStarted>(_onSplashStarted);
  }

  Future<void> _onSplashStarted(
      SplashStarted event, Emitter<SplashState> emit) async {
    emit(state.copyWith(status: SplashStatus.loading));

    // TODO: later -> check saved token / login state
    await Future.delayed(const Duration(seconds: 2));

    // For now always go to welcome
    emit(state.copyWith(status: SplashStatus.goToWelcome));
  }
}
