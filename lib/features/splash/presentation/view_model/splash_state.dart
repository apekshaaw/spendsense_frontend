enum SplashStatus {
  initial,
  loading,
  goToWelcome,
  goToDashboard,
}

class SplashState {
  final SplashStatus status;

  const SplashState({this.status = SplashStatus.initial});

  SplashState copyWith({SplashStatus? status}) {
    return SplashState(
      status: status ?? this.status,
    );
  }
}
