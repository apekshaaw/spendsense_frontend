import 'package:flutter/material.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  static const Color _bg = Color(0xFFEAF5FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (same style as your Settings/Profile)
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  const Text(
                    'HELP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),

              const Text(
                'How SpendSense works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F4978),
                ),
              ),
              const SizedBox(height: 12),

              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SpendSense helps you reduce impulse buys by tracking Wants vs Needs and growing your savings progress.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    SizedBox(height: 12),
                    _Bullet(text: 'Wants: optional purchases (can be Skipped or Purchased).'),
                    _Bullet(text: 'Needs: important spending (tracked separately).'),
                    _Bullet(text: 'Goal: your target savings amount, updated by entries you add.'),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'FAQs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F4978),
                ),
              ),
              const SizedBox(height: 12),

              const _FaqTile(
                q: 'What happens when I “Skip” a want?',
                a: 'Skipped wants contribute to your “savings” progress and help build your streak.',
              ),
              const _FaqTile(
                q: 'What happens when I “Purchase” a want?',
                a: 'Purchased wants count as spending and can affect your progress and streak.',
              ),
              const _FaqTile(
                q: 'Is “Saving vs Spending” calculated from Needs too?',
                a: 'No. It is calculated from Wants only (Skipped = Saving, Purchased = Spending) within the selected range.',
              ),
              const _FaqTile(
                q: 'How do I update my profile photo?',
                a: 'Go to Edit Profile → choose a photo. If none is selected, the default avatar is used.',
              ),

              const SizedBox(height: 18),
              const Text(
                'Contact & Support',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F4978),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ Non-clickable static rows
              _Card(
                child: Column(
                  children: const [
                    _StaticRow(
                      title: 'Report a bug',
                      subtitle: 'Send us what happened + screenshot',
                      icon: Icons.bug_report_outlined,
                    ),
                    Divider(height: 1),
                    _StaticRow(
                      title: 'Contact email',
                      subtitle: 'spendsense.support@gmail.com',
                      icon: Icons.email_outlined,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              _Card(
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF1F4978)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'App version: 0.1 (Demo)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w800)),
        children: [
          Text(a, style: const TextStyle(color: Colors.black87, height: 1.35)),
        ],
      ),
    );
  }
}

class _StaticRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _StaticRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1F4978)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
