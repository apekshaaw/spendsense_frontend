// lib/features/profile/presentation/view_model/profile_state.dart
import '../../data/models/profile_model.dart';

enum ProfileStatus { initial, loading, ready, error }

class ProfileState {
  final ProfileStatus status;
  final ProfileModel? profile;
  final String? errorMessage;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileModel? profile,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}
