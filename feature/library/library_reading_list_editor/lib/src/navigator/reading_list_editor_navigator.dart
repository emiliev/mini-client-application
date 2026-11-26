/// What library_reading_list_editor needs from outside: intents in the
/// feature's own language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/library_wiring` (T-0048). Only blocs call it.
///
/// The editor's result (the saved list) does not go through the navigator:
/// the flow completes with it (`ReadingListEditorFlow.onComplete`) and the
/// wiring hands it back to whoever opened the editor (plan 01 §4.3).
abstract interface class ReadingListEditorNavigator {
  /// Reading lists belong to a signed-in user. Completes with true once
  /// someone is signed in, false when the user backed out. The feature does
  /// not know how signing in works; the app decides (a sheet, a route).
  Future<bool> requestSignIn();
}
