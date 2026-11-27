import 'package:flutter/foundation.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';

/// What the library group's typed routes build (R15): each member returns a
/// feature's `*Flow`. The route files import only this interface;
/// `LibraryRouteTargetsImpl` (unannotated) supplies the flows' navigators and
/// is registered by `LibraryWiringDIInitializer`.
///
/// A flow that ends with a result takes the route's `onComplete` in the
/// app-level type (`String`, the list id): the implementation maps the
/// feature's own type (`ReadingListId`) to it, since features never share
/// types (plan 01 §4.3).
///
/// Prefixed with the group because the app imports every wiring's barrel
/// side by side (F-0040 fact 11).
abstract interface class LibraryRouteTargets {
  /// The reading-list editor on a new list: `/me/lists/new`. [onComplete]
  /// gets the new list's id, or null when it ended without saving.
  ReadingListEditorFlow newReadingList({
    required ValueChanged<String?> onComplete,
  });

  /// The reading-list editor on list [id]: `/me/lists/:id/edit`.
  ReadingListEditorFlow editReadingList(
    String id, {
    required ValueChanged<String?> onComplete,
  });
}
