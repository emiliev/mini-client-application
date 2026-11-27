part of 'trivia_setup_bloc.dart';

/// What the setup page asks for (Tide's sealed events).
sealed class TriviaSetupEvent {
  const TriviaSetupEvent();

  /// The first load: the page adds it once it is shown.
  const factory TriviaSetupEvent.load() = _Load;

  /// Retry after the categories failed to load.
  const factory TriviaSetupEvent.retry() = _Retry;

  /// The page is shown again (a round, its results or another screen above
  /// it closed): the best scores are read again.
  const factory TriviaSetupEvent.shownAgain() = _ShownAgain;

  const factory TriviaSetupEvent.selectCategory(String id) = _SelectCategory;

  const factory TriviaSetupEvent.selectDifficulty(TriviaDifficulty difficulty) =
      _SelectDifficulty;

  /// Start was tapped: the round opens.
  const factory TriviaSetupEvent.start() = _Start;
}

final class _Load extends TriviaSetupEvent {
  const _Load();
}

final class _Retry extends TriviaSetupEvent {
  const _Retry();
}

final class _ShownAgain extends TriviaSetupEvent {
  const _ShownAgain();
}

final class _SelectCategory extends TriviaSetupEvent {
  const _SelectCategory(this.id);

  final String id;
}

final class _SelectDifficulty extends TriviaSetupEvent {
  const _SelectDifficulty(this.difficulty);

  final TriviaDifficulty difficulty;
}

final class _Start extends TriviaSetupEvent {
  const _Start();
}

/// Internal: `SessionReader.authState` changed, or a best-score answer
/// belonged to a session that is gone.
final class _SessionChanged extends TriviaSetupEvent {
  const _SessionChanged();
}
