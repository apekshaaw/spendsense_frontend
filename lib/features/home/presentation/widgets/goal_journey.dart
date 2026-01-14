import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'goal_icon.dart';

class GoalJourney extends StatelessWidget {
  final double progress; // 0..1
  final String goalName;
  final String boyLottie; // icon/animation for boy

  const GoalJourney({
    super.key,
    required this.progress,
    required this.goalName,
    required this.boyLottie,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const avatarSize = 52.0;
          const goalSize = 56.0;

          final usableWidth = constraints.maxWidth - avatarSize - goalSize;
          final x = usableWidth * progress.clamp(0, 1);

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RoadPainter()),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                left: x,
                top: (92 - avatarSize) / 2,
                child: SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: Lottie.asset(
                    boyLottie,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Positioned(
                right: 0,
                top: (92 - goalSize) / 2,
                child: GoalIcon(goalName: goalName, size: goalSize),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    final base = Paint()
      ..color = Colors.blue.withOpacity(0.10)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), base);

    final dashPaint = Paint()
      ..color = Colors.blue.withOpacity(0.18)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const dashWidth = 10.0;
    const dashSpace = 8.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), dashPaint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
