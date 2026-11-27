import 'package:mc_fixtures_editorial/src/data/bank.dart';

/// Points for a correct answer, before bonuses.
const int basePoints = 100;

/// The most the time bonus can add (an answer at 0 ms).
const int maxTimeBonus = 50;

/// What each consecutive correct answer after the first adds.
const int streakStep = 25;

/// One submitted answer: `choiceId` null means no answer was given.
final class SubmittedAnswer {
  const SubmittedAnswer(this.choiceId, this.elapsedMs);

  final String? choiceId;
  final int elapsedMs;
}

/// How an answer was judged.
enum Outcome { correct, wrong, timeout }

/// One scored answer.
final class ScoredAnswer {
  const ScoredAnswer(this.questionId, this.outcome, this.points);

  final String questionId;
  final Outcome outcome;
  final int points;

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'outcome': outcome.name,
    'points': points,
  };
}

/// The result of scoring a round.
final class RoundScore {
  const RoundScore(this.answers);

  final List<ScoredAnswer> answers;

  int get score => answers.fold(0, (sum, a) => sum + a.points);

  int get correct => answers.where((a) => a.outcome == Outcome.correct).length;
}

/// Scores [answers] (by question id) against [questions], in the order of
/// [questions]. All integer arithmetic; the rules are in `CONTRACT.md`.
RoundScore scoreRound(
  List<TriviaQuestion> questions,
  Map<String, SubmittedAnswer> answers,
) {
  final scored = <ScoredAnswer>[];
  var streak = 0;
  for (final q in questions) {
    final answer = answers[q.id]!;
    final limitMs = q.timeLimitSeconds * 1000;
    if (answer.choiceId == null || answer.elapsedMs >= limitMs) {
      streak = 0;
      scored.add(ScoredAnswer(q.id, Outcome.timeout, 0));
    } else if (answer.choiceId != q.correctChoiceId) {
      streak = 0;
      scored.add(ScoredAnswer(q.id, Outcome.wrong, 0));
    } else {
      streak++;
      final timeBonus = maxTimeBonus * (limitMs - answer.elapsedMs) ~/ limitMs;
      scored.add(
        ScoredAnswer(
          q.id,
          Outcome.correct,
          basePoints + timeBonus + streakStep * (streak - 1),
        ),
      );
    }
  }
  return RoundScore(scored);
}
