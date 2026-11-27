import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:trivia_quiz/src/domain/engine/scoring.dart';

/// The screen names of the flow's three pages: their `McFlowPage` names,
/// which `AnalyticsFlowObserver` tracks. The setup page and the play page
/// are each the first page of a flow whose route has the same name
/// (`/trivia` is `trivia_setup`, `/trivia/play` is `trivia_play`), so neither
/// is tracked twice (ADR-0012).
const String triviaSetupScreen = 'trivia_setup';
const String triviaPlayScreen = 'trivia_play';
const String triviaResultsScreen = 'trivia_results';

/// A round's first question is shown.
const String triviaRoundStartedEvent = 'trivia_round_started';

/// A question was answered or timed out.
const String triviaAnswerEvent = 'trivia_answer';

/// The last question was answered: the local score.
const String triviaRoundFinishedEvent = 'trivia_round_finished';

/// How long an answer took, as the `elapsed_bucket` parameter: whole
/// quarters of the question's limit (`q1` is the first quarter), or
/// `timeout`. Quarters, so every difficulty has the same four buckets.
String elapsedBucket(AnswerOutcome outcome, int elapsedMs, int limitMs) {
  if (outcome == AnswerOutcome.timeout) {
    return 'timeout';
  }
  return 'q${4 * elapsedMs ~/ limitMs + 1}';
}

/// The quiz's analytics vocabulary over the blocs' pure-Dart port
/// (`AnalyticsTracker`, ADR-0012): event names and params are spelled once,
/// here.
extension TriviaTracking on AnalyticsTracker {
  /// `trivia_round_started` with `category` and `difficulty`.
  void roundStarted(String category, String difficulty) => trackEvent(
    triviaRoundStartedEvent,
    {'category': category, 'difficulty': difficulty},
  );

  /// `trivia_answer` with `correct` and `elapsed_bucket`.
  void answered(AnswerOutcome outcome, int elapsedMs, int limitMs) =>
      trackEvent(triviaAnswerEvent, {
        'correct': outcome == AnswerOutcome.correct,
        'elapsed_bucket': elapsedBucket(outcome, elapsedMs, limitMs),
      });

  /// `trivia_round_finished` with `score` (the engine's).
  void roundFinished(int score) =>
      trackEvent(triviaRoundFinishedEvent, {'score': score});
}
