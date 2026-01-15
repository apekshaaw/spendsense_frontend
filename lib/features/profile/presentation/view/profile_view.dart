import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../common/widgets/spendsense_bottom_nav_bar.dart';
import '../view_model/profile_view_model.dart';
import '../view_model/profile_event.dart';
import '../view_model/profile_state.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _currentIndex = 4;

  @override
  void initState() {
    super.initState();
    context.read<ProfileViewModel>().add(LoadProfile());
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
        break;
      case 1:
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.stats, (r) => false);
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.addGoal);
        break;
      case 3:
        Navigator.of(context).pushNamed(AppRoutes.alerts);
        break;
      case 4:
        break;
    }
  }

  Future<void> _logout() async {
    context.read<ProfileViewModel>().add(LogoutProfile());
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (r) => false);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Are You Sure You Want To Log Out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ Yes, Log Out (filled)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // close popup first
                      _logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Yes, Log Out',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ Cancel (outlined)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ImageProvider _avatarProvider(String avatarUrl) {
    if (avatarUrl.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }

    try {
      final clean = avatarUrl.contains(',') ? avatarUrl.split(',').last : avatarUrl;
      final bytes = base64Decode(clean);
      return MemoryImage(bytes);
    } catch (_) {
      return const AssetImage('assets/images/default_avatar.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      bottomNavigationBar: SpendSenseBottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onNavTap,
      ),
      body: SafeArea(
        child: BlocBuilder<ProfileViewModel, ProfileState>(
          builder: (context, state) {
            final profile = state.profile;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF5FF),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            const Text(
                              'PROFILE',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 44,
                          backgroundImage: _avatarProvider(profile?.avatarUrl ?? ""),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile?.name ?? "Loading...",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile?.email ?? "",
                          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 12),
                        if (state.status == ProfileStatus.loading && profile == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: CircularProgressIndicator(),
                          ),
                        if (state.status == ProfileStatus.error)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              state.errorMessage ?? "Something went wrong",
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        ProfileOptionTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.editProfile);
                          },
                        ),
                        const SizedBox(height: 16),
                        ProfileOptionTile(
                          icon: Icons.settings_outlined,
                          label: 'Setting',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.settings);
                          },
                        ),
                        const SizedBox(height: 16),
                        ProfileOptionTile(
                          icon: Icons.headset_mic_outlined,
                          label: 'Help',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.help);
                          },
                        ),
                        const SizedBox(height: 16),

                        // ✅ Logout now opens popup (no new page)
                        ProfileOptionTile(
                          icon: Icons.logout_rounded,
                          label: 'Logout',
                          isDestructive: true,
                          onTap: _showLogoutDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const ProfileOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg = isDestructive ? const Color(0xFFFFE5E5) : const Color(0xFFE0F0FF);
    final Color iconColor = isDestructive ? Colors.red : AppColors.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
