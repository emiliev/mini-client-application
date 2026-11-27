import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The countdown ring of the play page: a track, and an arc of the time
/// left that starts at 12 o'clock and shrinks clockwise. The play bloc
/// redraws it every frame tick (100 ms); with reduce motion the page shows
/// the number only and never builds this painter.
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    this.strokeWidth = 6,
  });

  /// The share of the time left, from 1 (just started) to 0 (timed out).
  final double fraction;
  final Color track;
  final Color fill;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, stroke..color = track);
    final left = fraction.clamp(0.0, 1.0);
    if (left > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * left,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(CountdownRingPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.fill != fill ||
      old.strokeWidth != strokeWidth;
}
