import 'package:trivia_quiz/src/domain/model/trivia.dart';

// The scoring rules of `mc_fixtures_editorial` CONTRACT.md ("Scoring"), in
// integer arithmetic only: the engine's numbers must equal the server's. The
// feature's Scenario Outline runs the contract's worked examples through the
// flow (R6), so a change here that the server does not make fails it.

/// Points for a correct answer, before bonuses.
const int basePoints = 100;

/// The most the time bonus adds (an answer at 0 ms).
const int maxTimeBonus = 50;

/// What each consecutive correct answer after the first adds.
const int streakStep = 25;

/// What a correct answer that used the 50/50 hint loses (CONTRACT.md rule 4).
const int hintPenalty = 50;

/// How an answer was judged.
enum AnswerOutcome { correct, wrong, timeout }

/// Judges [choiceId] (null: no answer) given at [elapsedMs] on [question].
/// A choice at or after the limit is a timeout, even the correct one.
AnswerOutcome judge(TriviaQuestion question, String? choiceId, int elapsedMs) {
  if (choiceId == null || elapsedMs >= question.limitMs) {
    return AnswerOutcome.timeout;
  }
  return choiceId == question.correctChoiceId
      ? AnswerOutcome.correct
      : AnswerOutcome.wrong;
}

/// The points of one answer. [streak] counts the correct answers in a row
/// up to and including this one (1 for the first of a run).
///
/// `timeBonus = (50 * (limitMs - elapsedMs)) ~/ limitMs`: the floor, so 50 at
/// 0 ms and 0 at `limitMs - 1`. `streakBonus = 25 * (streak - 1)`, uncapped.
int pointsFor(
  AnswerOutcome outcome, {
  required int elapsedMs,
  required int limitMs,
  required int streak,
  required bool hint,
}) {
  if (outcome != AnswerOutcome.correct) {
    return 0;
  }
  final timeBonus = maxTimeBonus * (limitMs - elapsedMs) ~/ limitMs;
  return basePoints +
      timeBonus +
      streakStep * (streak - 1) -
      (hint ? hintPenalty : 0);
}
