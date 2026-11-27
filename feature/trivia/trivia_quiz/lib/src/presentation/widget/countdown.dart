import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:trivia_quiz/src/presentation/painter/countdown_ring_painter.dart';
import 'package:trivia_quiz/src/presentation/widget/trivia_common.dart';

/// Keys of the countdown, for tests.
const countdownKey = ValueKey<String>('trivia_play.countdown');
const countdownRingKey = ValueKey<String>('trivia_play.countdown.ring');
const countdownNumberKey = ValueKey<String>('trivia_play.countdown.number');

/// The seconds left on the question, inside a ring of the time left. With
/// reduce motion (`MediaQuery.disableAnimations`) the ring is not drawn: the
/// number only, so nothing moves on screen.
class Countdown extends StatelessWidget {
  const Countdown({
    required this.remainingMs,
    required this.limitMs,
    required this.paused,
    super.key,
  });

  final int remainingMs;
  final int limitMs;
  final bool paused;

  /// At or under a quarter of the limit the ring turns urgent.
  bool get _urgent => remainingMs * 4 <= limitMs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    final seconds = secondsLeft(remainingMs);
    final number = Text(
      paused ? l10n.triviaPaused : '$seconds',
      key: countdownNumberKey,
      style: paused ? text.labelSmall : text.titleLarge,
    );
    return Semantics(
      key: countdownKey,
      label: l10n.triviaSecondsLeft(seconds),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 64,
        child: MediaQuery.disableAnimationsOf(context)
            ? Center(child: number)
            : CustomPaint(
                key: countdownRingKey,
                painter: CountdownRingPainter(
                  fraction: limitMs == 0 ? 0 : remainingMs / limitMs,
                  track: p.surfaceVariant,
                  fill: _urgent ? p.error : p.primary,
                ),
                child: Center(child: number),
              ),
      ),
    );
  }
}
