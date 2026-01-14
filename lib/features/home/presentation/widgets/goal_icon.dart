import 'package:flutter/material.dart';

class GoalIcon extends StatelessWidget {
  final String goalName;
  final double size;

  const GoalIcon({
    super.key,
    required this.goalName,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final name = goalName.trim();
    final emoji = _extractEmoji(name);

    if (emoji != null) {
      return _CircleWrap(
        size: size,
        child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
      );
    }

    final icon = _pickMaterialIcon(name.toLowerCase());
    if (icon != null) {
      return _CircleWrap(
        size: size,
        child: Icon(icon, size: size * 0.55, color: Theme.of(context).primaryColor),
      );
    }

    final letter = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.25)),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  String? _extractEmoji(String text) {
    for (final r in text.runes) {
      if (r > 10000) return String.fromCharCode(r);
    }
    return null;
  }

  IconData? _pickMaterialIcon(String n) {
    if (n.contains('car') || n.contains('ride') || n.contains('vehicle')) return Icons.directions_car_rounded;
    if (n.contains('shoe') || n.contains('sneaker') || n.contains('boot')) return Icons.hiking_rounded;
    if (n.contains('phone') || n.contains('iphone') || n.contains('mobile')) return Icons.smartphone_rounded;
    if (n.contains('laptop') || n.contains('macbook') || n.contains('pc')) return Icons.laptop_mac_rounded;
    if (n.contains('watch')) return Icons.watch_rounded;
    if (n.contains('trip') || n.contains('travel') || n.contains('vacation')) return Icons.flight_takeoff_rounded;
    if (n.contains('house') || n.contains('rent') || n.contains('room')) return Icons.home_rounded;
    if (n.contains('gift')) return Icons.card_giftcard_rounded;
    if (n.contains('camera')) return Icons.photo_camera_rounded;
    if (n.contains('game') || n.contains('ps') || n.contains('xbox')) return Icons.sports_esports_rounded;
    if (n.contains('gym') || n.contains('fitness')) return Icons.fitness_center_rounded;
    return null;
  }
}

class _CircleWrap extends StatelessWidget {
  final double size;
  final Widget child;

  const _CircleWrap({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: child,
    );
  }
}
