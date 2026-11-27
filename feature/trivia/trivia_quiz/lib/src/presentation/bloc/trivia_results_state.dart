part of 'trivia_results_bloc.dart';

/// The results page's save state (Tide's shape, R16). The round itself, as
/// the engine scored it, is [TriviaResultsBloc.finished].
@freezed
sealed class TriviaResultsState with _$TriviaResultsState {
  /// The result is on its way to the server.
  const factory TriviaResultsState.saving() = _Saving;

  /// Saved: the server's score (authoritative) and the best score.
  const factory TriviaResultsState.saved(ServerResult result) = _Saved;

  /// Not saved (a failed post, or the session changed meanwhile): the local
  /// score with Retry. `McBloc` reports it.
  @Implements<McFailureState>()
  const factory TriviaResultsState.notSaved(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _NotSaved;

  /// Nobody is signed in: the local score, and "Save your score".
  const factory TriviaResultsState.signedOut() = _SignedOut;

  /// The app is signing someone in for this save (`requestSignIn()`). A
  /// static message, no spinner: it may wait indefinitely (F-0048 §5.10).
  const factory TriviaResultsState.signingIn() = _SigningIn;
}
