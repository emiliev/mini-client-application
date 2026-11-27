import 'package:flutter/material.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:trivia_quiz/src/domain/engine/scoring.dart';
import 'package:trivia_quiz/src/flow/trivia_quiz_flow_state.dart';
import 'package:trivia_quiz/src/presentation/widget/trivia_common.dart';

/// Keys of the breakdown charts, for tests.
const breakdownDonutKey = ValueKey<String>('trivia_results.donut');
const breakdownBarsKey = ValueKey<String>('trivia_results.bars');

/// The results breakdown: an `McDonutChart` of the outcomes (correct, wrong,
/// timed out) and an `McBarChart` of the points per question ([points]: the
/// server's once saved, else the engine's).
class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({
    required this.finished,
    required this.points,
    super.key,
  });

  final FinishedRound finished;
  final List<int> points;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    int count(AnswerOutcome o) =>
        finished.answers.where((a) => a.outcome == o).length;
    final correct = count(AnswerOutcome.correct);
    final wrong = count(AnswerOutcome.wrong);
    final timeout = count(AnswerOutcome.timeout);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.triviaBreakdownTitle, style: text.titleMedium),
        ),
        const McGap.sm(),
        Center(
          child: McDonutChart(
            key: breakdownDonutKey,
            size: 180,
            semanticLabel: l10n.triviaBreakdownSummary(correct, wrong, timeout),
            emptyMessage: l10n.triviaNoPoints,
            centerLabel: '$correct/${finished.answers.length}',
            data: [
              McDonutSegment(
                label: l10n.triviaOutcomeCorrect,
                value: correct.toDouble(),
                role: McChartRole.positive,
              ),
              McDonutSegment(
                label: l10n.triviaOutcomeWrong,
                value: wrong.toDouble(),
                role: McChartRole.negative,
              ),
              McDonutSegment(
                label: l10n.triviaOutcomeTimeout,
                value: timeout.toDouble(),
                role: McChartRole.neutral,
              ),
            ],
          ),
        ),
        const McGap.lg(),
        Semantics(
          header: true,
          child: Text(l10n.triviaPointsTitle, style: text.titleMedium),
        ),
        const McGap.sm(),
        McBarChart(
          key: breakdownBarsKey,
          height: 200,
          semanticLabel: l10n.triviaPointsSummary(points.length),
          emptyMessage: l10n.triviaNoPoints,
          data: [
            for (var i = 0; i < points.length; i++)
              McBarDatum(
                label: '${i + 1}',
                value: points[i].toDouble(),
                role: points[i] > 0 ? McChartRole.series1 : McChartRole.neutral,
              ),
          ],
        ),
      ],
    );
  }
}
