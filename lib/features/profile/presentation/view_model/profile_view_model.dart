import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spendsense_frontend/features/profile/data/datasorces/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/profile_repository_impl.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileViewModel extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repo;

  ProfileViewModel({ProfileRepository? repo})
      : _repo = repo ??
            ProfileRepositoryImpl(
              remote: ProfileRemoteDataSourceImpl(),
            ),
        super(const ProfileState()) {
    on<LoadProfile>(_onLoadProfile);
    on<RefreshProfile>(_onRefreshProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<LogoutProfile>(_onLogout);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading, errorMessage: null));

    try {
      final cached = await _repo.getCachedProfile();
      if (cached != null) {
        emit(state.copyWith(status: ProfileStatus.ready, profile: cached));
      }

      final fresh = await _repo.fetchProfile();
      emit(state.copyWith(status: ProfileStatus.ready, profile: fresh));
    } catch (e) {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefreshProfile(
    RefreshProfile event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final fresh = await _repo.fetchProfile();
      emit(state.copyWith(status: ProfileStatus.ready, profile: fresh));
    } catch (_) {}
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.profile == null) return;

    emit(state.copyWith(status: ProfileStatus.loading, errorMessage: null));

    try {
      final updated = state.profile!.copyWith(
        name: event.name,
        email: event.email,
        phone: event.phone,
        darkMode: event.darkMode,
        avatarUrl: event.avatarUrl,
      );

      final saved = await _repo.updateProfile(updated);
      emit(state.copyWith(status: ProfileStatus.ready, profile: saved));
    } catch (e) {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLogout(LogoutProfile event, Emitter<ProfileState> emit) async {
    await _repo.clearCache();
    emit(const ProfileState(status: ProfileStatus.initial));
  }
}
