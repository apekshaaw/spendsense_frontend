import 'package:flutter/material.dart';

class TermsView extends StatelessWidget {
  const TermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header (matches your Settings header style)
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
                    'TERMS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle("1. About SpendSense"),
                      _SectionBody(
                        "SpendSense is a personal finance tracking app (demo/student project). "
                        "It helps you record Wants, Needs, and Goals to reflect on spending habits.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("2. Account & Usage"),
                      _SectionBody(
                        "You are responsible for keeping your login information secure. "
                        "Do not misuse the app or attempt to access other users’ data.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("3. Data & Privacy (Basic)"),
                      _SectionBody(
                        "SpendSense may store your profile details and your entries (wants, needs, goals). "
                        "If the app is connected to a backend, data may be stored on a server. "
                        "You can request deletion by using the Delete Account option.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("4. No Financial Advice"),
                      _SectionBody(
                        "SpendSense is for tracking and self-improvement only. "
                        "It does not provide financial, investment, or legal advice.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("5. App Availability"),
                      _SectionBody(
                        "Because this app is under development, features may change, break, or be removed. "
                        "The app may occasionally be unavailable.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("6. Limitation of Liability"),
                      _SectionBody(
                        "We are not responsible for any losses, missed savings, or decisions made based on the app. "
                        "Use the app at your own discretion.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("7. Changes to These Terms"),
                      _SectionBody(
                        "These terms may be updated as the app improves. "
                        "If updated, the newest version will replace the old one.",
                      ),
                      SizedBox(height: 14),

                      _SectionTitle("8. Contact"),
                      _SectionBody(
                        "If you have questions, contact: spendsense.support@example.com",
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1F4978),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.45,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
