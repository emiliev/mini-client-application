part of 'reading_list_editor_bloc.dart';

/// What the step pages ask for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories.
sealed class ReadingListEditorEvent {
  const ReadingListEditorEvent();

  /// Loads the list again after a failed load (edit mode).
  const factory ReadingListEditorEvent.retry() = _Retry;

  const factory ReadingListEditorEvent.nameChanged(String name) = _NameChanged;

  const factory ReadingListEditorEvent.descriptionChanged(String text) =
      _DescriptionChanged;

  const factory ReadingListEditorEvent.visibilityChanged(
    ReadingListVisibility visibility,
  ) = _VisibilityChanged;

  /// A text field lost focus: its error may show.
  const factory ReadingListEditorEvent.touched(String field) = _Touched;

  /// A search result was tapped: it joins the list, or leaves it when it is
  /// already picked.
  const factory ReadingListEditorEvent.comicToggled(PickedComic comic) =
      _ComicToggled;

  /// Step 3: the comic at [from] moves to position [to] (both 0-based,
  /// positions in the list before the move).
  const factory ReadingListEditorEvent.comicMoved(int from, int to) =
      _ComicMoved;

  /// Next on a valid step.
  const factory ReadingListEditorEvent.next() = _Next;

  /// A tap on the disabled Next: shows why the step is invalid.
  const factory ReadingListEditorEvent.blockedNext() = _BlockedNext;

  /// Back in the step bar (a back gesture pops the step page instead, which
  /// the bloc hears from the flow).
  const factory ReadingListEditorEvent.back() = _Back;

  /// Finish on the last step, and Retry after a failed save.
  const factory ReadingListEditorEvent.submit() = _Submit;

  /// Close on a page the editor cannot continue from (the session changed):
  /// the flow ends with no result.
  const factory ReadingListEditorEvent.close() = _Close;
}

final class _Retry extends ReadingListEditorEvent {
  const _Retry();
}

final class _NameChanged extends ReadingListEditorEvent {
  const _NameChanged(this.name);

  final String name;
}

final class _DescriptionChanged extends ReadingListEditorEvent {
  const _DescriptionChanged(this.text);

  final String text;
}

final class _VisibilityChanged extends ReadingListEditorEvent {
  const _VisibilityChanged(this.visibility);

  final ReadingListVisibility visibility;
}

final class _Touched extends ReadingListEditorEvent {
  const _Touched(this.field);

  final String field;
}

final class _ComicToggled extends ReadingListEditorEvent {
  const _ComicToggled(this.comic);

  final PickedComic comic;
}

final class _ComicMoved extends ReadingListEditorEvent {
  const _ComicMoved(this.from, this.to);

  final int from;
  final int to;
}

final class _Next extends ReadingListEditorEvent {
  const _Next();
}

final class _BlockedNext extends ReadingListEditorEvent {
  const _BlockedNext();
}

final class _Back extends ReadingListEditorEvent {
  const _Back();
}

final class _Submit extends ReadingListEditorEvent {
  const _Submit();
}

final class _Close extends ReadingListEditorEvent {
  const _Close();
}

/// Internal: the editor opens (sign-in gate, then the load in edit mode).
final class _Start extends ReadingListEditorEvent {
  const _Start();
}

/// Internal: the wizard reported a new state (outside any handler; an event
/// brings it back into the bloc, so only a handler emits).
final class _WizardChanged extends ReadingListEditorEvent {
  const _WizardChanged(this.wizard);

  final WizardState<ReadingListId> wizard;
}

/// Internal: `SessionReader.authState` changed (a sign-in or a sign-out,
/// here or anywhere else in the app).
final class _SessionChanged extends ReadingListEditorEvent {
  const _SessionChanged();
}
