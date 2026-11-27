part of 'trivia_setup_bloc.dart';

/// The setup page's state (Tide's shape, R16).
@freezed
sealed class TriviaSetupState with _$TriviaSetupState {
  const factory TriviaSetupState.loading() = _Loading;

  /// The categories, the selection, and the signed-in user's best score per
  /// category id ([best] is null signed out, or when it could not be read).
  const factory TriviaSetupState.ready({
    required List<TriviaCategory> categories,
    required String category,
    required TriviaDifficulty difficulty,
    Map<String, int>? best,
  }) = _Ready;

  /// The server has no categories (`trivia.empty`).
  const factory TriviaSetupState.empty() = _Empty;

  @Implements<McFailureState>()
  const factory TriviaSetupState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
