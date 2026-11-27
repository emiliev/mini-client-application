part of 'trivia_play_bloc.dart';

/// The play page's state (Tide's shape, R16).
@freezed
sealed class TriviaPlayState with _$TriviaPlayState {
  /// The round is loading.
  const factory TriviaPlayState.loading() = _Loading;

  /// The round could not be loaded (`McBloc` reports it).
  @Implements<McFailureState>()
  const factory TriviaPlayState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;

  /// A question is asked or revealed.
  const factory TriviaPlayState.playing(PlayView view) = _Playing;
}

/// What the play page shows of the current question.
@freezed
abstract class PlayView with _$PlayView {
  const factory PlayView({
    required TriviaQuestion question,

    /// From 1.
    required int number,
    required int total,

    /// What is left on the countdown; frozen while paused and once revealed.
    required int remainingMs,

    /// The judged answer, once the question is revealed; null while asking.
    required AnsweredQuestion? answer,
    required int score,
    required int streak,

    /// The choices the 50/50 hint hid.
    required Set<String> hidden,

    /// Whether the hint can be used now.
    required bool hintOffered,
    required bool paused,

    /// The quit dialog should be open.
    required bool confirmingQuit,
    required bool isLast,
  }) = _PlayView;
}
