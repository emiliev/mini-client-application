part of 'trivia_results_bloc.dart';

/// What the results page asks for (Tide's sealed events).
sealed class TriviaResultsEvent {
  const TriviaResultsEvent();

  /// The page is shown: signed in, the result is saved.
  const factory TriviaResultsEvent.start() = _Start;

  /// Signed out, "Save your score" was tapped.
  const factory TriviaResultsEvent.save() = _Save;

  /// Retry after the result was not saved.
  const factory TriviaResultsEvent.retry() = _Retry;

  /// A new round of the same category and difficulty.
  const factory TriviaResultsEvent.playAgain() = _PlayAgain;

  /// A question's comic was tapped.
  const factory TriviaResultsEvent.openComic(ComicId id) = _OpenComic;
}

final class _Start extends TriviaResultsEvent {
  const _Start();
}

final class _Save extends TriviaResultsEvent {
  const _Save();
}

final class _Retry extends TriviaResultsEvent {
  const _Retry();
}

final class _PlayAgain extends TriviaResultsEvent {
  const _PlayAgain();
}

final class _OpenComic extends TriviaResultsEvent {
  const _OpenComic(this.id);

  final ComicId id;
}
