import 'package:flutter/foundation.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:library_wiring/src/routes/route_targets.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it), and maps each flow's result to the app-level type.
class LibraryRouteTargetsImpl implements LibraryRouteTargets {
  const LibraryRouteTargetsImpl({
    required ReadingListEditorNavigator readingListEditor,
  }) : _readingListEditor = readingListEditor;

  final ReadingListEditorNavigator _readingListEditor;

  @override
  ReadingListEditorFlow newReadingList({
    required ValueChanged<String?> onComplete,
  }) => ReadingListEditorFlow(
    navigator: _readingListEditor,
    onComplete: (id) => onComplete(id?.value),
  );

  @override
  ReadingListEditorFlow editReadingList(
    String id, {
    required ValueChanged<String?> onComplete,
  }) => ReadingListEditorFlow(
    navigator: _readingListEditor,
    editing: ReadingListId(id),
    onComplete: (saved) => onComplete(saved?.value),
  );
}
