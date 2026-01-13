import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReminderResultType { skipped, purchased }

class ReminderResultDialog extends StatelessWidget {
  final ReminderResultType type;
  final String wantName;
  final double wantPrice;
  final int streakDays;
  final String message;

  const ReminderResultDialog({
    super.key,
    required this.type,
    required this.wantName,
    required this.wantPrice,
    required this.streakDays,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isSkip = type == ReminderResultType.skipped;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              child: isSkip
                  ? Lottie.asset('assets/anim/thumbs_up.json')
                  : Lottie.asset('assets/anim/sad_tear.json'),
            ),
            const SizedBox(height: 8),
            Text(
              isSkip ? "Great job!" : "No worries.",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    isSkip
                        ? 'You saved Rs${wantPrice.toStringAsFixed(0)}'
                        : 'You spent Rs${wantPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSkip
                        ? '🔥 Streak: $streakDays day(s)'
                        : 'Streak reset — restart tomorrow 💪',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSkip ? const Color(0xFF123A63) : const Color(0xFF2E7BFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String> pickMessage({
    required ReminderResultType type,
    required String wantName,
    required double wantPrice,
    required int streakDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == ReminderResultType.skipped ? 'msg_idx_skip' : 'msg_idx_buy';
    final lastIdx = prefs.getInt(key) ?? -1;

    final list = type == ReminderResultType.skipped
        ? _skipMessages(wantName, wantPrice, streakDays)
        : _buyMessages(wantName, wantPrice);

    int idx = Random().nextInt(list.length);
    if (list.length > 1 && idx == lastIdx) idx = (idx + 1) % list.length;

    await prefs.setInt(key, idx);
    return list[idx];
  }

  static List<String> _skipMessages(String wantName, double wantPrice, int streak) => [
        "✅ You skipped “$wantName”. That’s Rs${wantPrice.toStringAsFixed(0)} protected.\nKeep it up 🔥",
        "🔥 Discipline win! You saved Rs${wantPrice.toStringAsFixed(0)}.\nStreak: $streak day(s).",
        "Big move 💪 You didn’t give in.\nOne decision at a time.",
        "Respect. Most people tap Buy.\nYou tapped Skip ✅",
      ];

  static List<String> _buyMessages(String wantName, double wantPrice) => [
        "It happens 😅 You bought “$wantName”.\nNo shame — we go again 💪",
        "One slip doesn’t define you.\nReset and come back stronger tomorrow.",
        "Okay — but you didn’t quit.\nNext reminder = next win.",
        "No guilt. Just feedback.\nCatch the trigger next time 👀",
      ];
}
