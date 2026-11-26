part of 'comic_picker_bloc.dart';

/// What the comics page asks the search for.
sealed class ComicPickerEvent {
  const ComicPickerEvent();

  /// The search field's text changed (every keystroke; the bloc debounces).
  const factory ComicPickerEvent.queryChanged(String text) = _QueryChanged;

  /// Search again after a failure.
  const factory ComicPickerEvent.retry() = _Retry;
}

final class _QueryChanged extends ComicPickerEvent {
  const _QueryChanged(this.text);

  final String text;
}

final class _Retry extends ComicPickerEvent {
  const _Retry();
}

/// Internal: typing paused on [query] (or the field was cleared).
final class _Search extends ComicPickerEvent {
  const _Search(this.query);

  final String query;
}
