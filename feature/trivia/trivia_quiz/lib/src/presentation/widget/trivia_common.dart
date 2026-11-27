import 'package:flutter/widgets.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/l10n/trivia_quiz_l10n.dart';

/// A shared shorthand for the feature's strings.
extension TriviaL10nContext on BuildContext {
  TriviaQuizL10n get triviaL10n => TriviaQuizL10n.of(this);
}

/// What the user reads for a failed request, from the shared error copy.
/// The raw failure text goes to monitoring only (`McBloc`).
String failureMessage(BuildContext context, ApiFailure failure) {
  final core = McL10nCoreL10n.of(context);
  return switch (failure) {
    ApiTimeout() => core.errorTimeout,
    ApiOffline() => core.errorNetwork,
    ApiServer() => core.errorServer,
    _ => core.errorGeneric,
  };
}

/// A difficulty's localised name.
String difficultyName(TriviaQuizL10n l10n, TriviaDifficulty difficulty) =>
    switch (difficulty) {
      TriviaDifficulty.easy => l10n.triviaEasy,
      TriviaDifficulty.medium => l10n.triviaMedium,
      TriviaDifficulty.hard => l10n.triviaHard,
    };

/// Seconds per question of each difficulty, for the setup page only: the
/// round itself carries each question's limit (`timeLimitSeconds`).
const Map<TriviaDifficulty, int> secondsPerQuestion = {
  TriviaDifficulty.easy: 20,
  TriviaDifficulty.medium: 15,
  TriviaDifficulty.hard: 10,
};

/// Whole seconds left, rounded up: 19 001 ms shows 20, 1 ms shows 1, and
/// only 0 ms shows 0.
int secondsLeft(int remainingMs) => (remainingMs + 999) ~/ 1000;
