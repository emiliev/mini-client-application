import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:trivia_quiz/src/domain/engine/trivia_engine.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';

part 'trivia_quiz_flow_state.freezed.dart';

/// What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,
/// so the blocs that update it stay Flutter-free (R15).
///
/// Pages: the setup (unless [linked]), then the play page while [round] is
/// set, or the results page once [result] is set. The results replace the
/// play page, so Back from the results never returns to a finished round.
@freezed
abstract class TriviaQuizFlowState with _$TriviaQuizFlowState {
  const factory TriviaQuizFlowState({
    /// The flow was opened at a round (`/trivia/play?...`): it has no setup
    /// page, so leaving the round leaves the flow (to the setup route below
    /// it, T-0049's nested back stack).
    @Default(false) bool linked,

    /// The round being played.
    RoundRequest? round,

    /// The round that was just played.
    FinishedRound? result,
  }) = _TriviaQuizFlowState;
}

/// Which round to play: the same three values always give the same round.
@freezed
abstract class RoundRequest with _$RoundRequest {
  const factory RoundRequest({
    required String category,
    required String difficulty,
    required int seed,
  }) = _RoundRequest;
}

/// A round played to the end: the questions, the engine's answers and its
/// score (the local one, shown until the server's arrives).
@freezed
abstract class FinishedRound with _$FinishedRound {
  const factory FinishedRound({
    required TriviaRound round,
    required List<AnsweredQuestion> answers,
    required int score,
    required int correct,
  }) = _FinishedRound;
}
