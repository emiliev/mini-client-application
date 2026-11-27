import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:trivia_quiz/src/presentation/painter/streak_meter_painter.dart';
import 'package:trivia_quiz/src/presentation/widget/trivia_common.dart';

/// Key of the streak meter, for tests.
const streakMeterKey = ValueKey<String>('trivia_play.streak');

/// The run of correct answers, as a meter of ten pills and a label.
class StreakMeter extends StatelessWidget {
  const StreakMeter({required this.streak, super.key});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final l10n = context.triviaL10n;
    return Semantics(
      label: l10n.triviaStreak(streak),
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 8,
              child: CustomPaint(
                key: streakMeterKey,
                painter: StreakMeterPainter(
                  streak: streak,
                  lit: p.series2,
                  unlit: p.surfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.triviaStreak(streak),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
