import 'package:flutter/material.dart';
import '../../../../app/routes.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5FF),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  const Text(
                    'SETTING',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Security',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F4978),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        _RowItem(
                          title: 'Change Password',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.changePassword),
                        ),
                        const Divider(height: 1),
                        _RowItem(
                          title: 'Terms And Conditions',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Terms And Conditions coming soon 📄')),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _RowItem(
                          title: 'Delete Account',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.deleteAccount),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _RowItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
