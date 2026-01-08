// lib/features/profile/data/repositories/profile_repository.dart
import '../models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel?> getCachedProfile();
  Future<ProfileModel> fetchProfile(); // from API
  Future<ProfileModel> updateProfile(ProfileModel updated);
  Future<void> clearCache();
}
  