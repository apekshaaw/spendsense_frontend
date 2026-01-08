// lib/features/profile/presentation/view_model/profile_event.dart
abstract class ProfileEvent {}

class LoadProfile extends ProfileEvent {}

class RefreshProfile extends ProfileEvent {}

class UpdateProfile extends ProfileEvent {
  final String name;
  final String email;
  final String phone;
  final bool darkMode;
  final String avatarUrl;

  UpdateProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.darkMode,
    required this.avatarUrl,
  });
}

class LogoutProfile extends ProfileEvent {}
