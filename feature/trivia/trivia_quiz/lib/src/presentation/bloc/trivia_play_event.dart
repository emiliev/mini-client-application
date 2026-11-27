part of 'trivia_play_bloc.dart';

/// What the play page asks for (Tide's sealed events).
sealed class TriviaPlayEvent {
  const TriviaPlayEvent();

  /// The page is shown for the first time: the round loads and starts.
  const factory TriviaPlayEvent.start() = _Start;

  /// Retry after the round failed to load.
  const factory TriviaPlayEvent.retry() = _Retry;

  /// A choice was tapped.
  const factory TriviaPlayEvent.answer(String choiceId) = _Answer;

  /// Next question (or the results, after the last).
  const factory TriviaPlayEvent.next() = _Next;

  /// The 50/50 hint was tapped.
  const factory TriviaPlayEvent.useHint() = _UseHint;

  /// The app came to the foreground ([foreground] true) or left it.
  const factory TriviaPlayEvent.foreground({required bool foreground}) =
      _Foreground;

  /// The round is visible in the app ([shown] true) or covered.
  const factory TriviaPlayEvent.shown({required bool shown}) = _Shown;

  /// Quit (the close button, or a pop of the page) was asked for.
  const factory TriviaPlayEvent.quitAsked() = _QuitAsked;

  /// The quit dialog's answer: [confirmed] leaves, otherwise the round
  /// resumes.
  const factory TriviaPlayEvent.quitAnswered({required bool confirmed}) =
      _QuitAnswered;
}

final class _Start extends TriviaPlayEvent {
  const _Start();
}

final class _Retry extends TriviaPlayEvent {
  const _Retry();
}

final class _Answer extends TriviaPlayEvent {
  const _Answer(this.choiceId);

  final String choiceId;
}

final class _Next extends TriviaPlayEvent {
  const _Next();
}

final class _UseHint extends TriviaPlayEvent {
  const _UseHint();
}

final class _Foreground extends TriviaPlayEvent {
  const _Foreground({required this.foreground});

  final bool foreground;
}

final class _Shown extends TriviaPlayEvent {
  const _Shown({required this.shown});

  final bool shown;
}

final class _QuitAsked extends TriviaPlayEvent {
  const _QuitAsked();
}

final class _QuitAnswered extends TriviaPlayEvent {
  const _QuitAnswered({required this.confirmed});

  final bool confirmed;
}

/// Internal: the countdown's frame timer.
final class _Tick extends TriviaPlayEvent {
  const _Tick();
}

/// Internal: the question's limit was reached.
final class _TimeUp extends TriviaPlayEvent {
  const _TimeUp();
}
