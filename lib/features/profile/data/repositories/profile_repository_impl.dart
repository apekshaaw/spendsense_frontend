import 'package:spendsense_frontend/features/profile/data/datasorces/profile_local_cache.dart';
import 'package:spendsense_frontend/features/profile/data/datasorces/profile_remote_datasource.dart';
import '../models/profile_model.dart';
import 'profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;

  ProfileRepositoryImpl({required this.remote});

  @override
  Future<ProfileModel?> getCachedProfile() async {
    return ProfileLocalCache.load();
  }

  @override
  Future<ProfileModel> fetchProfile() async {
    final profile = await remote.getMe();
    await ProfileLocalCache.save(profile);
    return profile;
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel updated) async {
    final profile = await remote.updateMe(
      name: updated.name,
      email: updated.email,
      phone: updated.phone,
      darkMode: updated.darkMode,
      avatarUrl: updated.avatarUrl,
    );
    await ProfileLocalCache.save(profile);
    return profile;
  }

  @override
  Future<void> clearCache() async {
    await ProfileLocalCache.clear();
  }
}
