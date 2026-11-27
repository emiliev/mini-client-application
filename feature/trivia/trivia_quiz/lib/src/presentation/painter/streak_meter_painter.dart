import 'package:flutter/rendering.dart';

/// The streak meter of the play page: [segments] pills in a row, the first
/// [streak] of them lit (a streak longer than the meter lights them all).
class StreakMeterPainter extends CustomPainter {
  const StreakMeterPainter({
    required this.streak,
    required this.lit,
    required this.unlit,
    this.segments = 10,
    this.gap = 3,
  });

  final int streak;
  final Color lit;
  final Color unlit;
  final int segments;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.width - gap * (segments - 1)) / segments;
    if (width <= 0) {
      return;
    }
    final radius = Radius.circular(size.height / 2);
    for (var i = 0; i < segments; i++) {
      final left = i * (width + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, width, size.height),
          radius,
        ),
        Paint()..color = i < streak ? lit : unlit,
      );
    }
  }

  @override
  bool shouldRepaint(StreakMeterPainter old) =>
      old.streak != streak ||
      old.lit != lit ||
      old.unlit != unlit ||
      old.segments != segments ||
      old.gap != gap;
}
