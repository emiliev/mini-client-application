part of 'reading_list_editor_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16).
@freezed
sealed class ReadingListEditorState with _$ReadingListEditorState {
  /// Opening: deciding whether to ask for a sign-in, or reading the list
  /// that is edited.
  const factory ReadingListEditorState.loading() = _Loading;

  /// The app is signing someone in (`requestSignIn()`); nothing else runs.
  const factory ReadingListEditorState.signingIn() = _SigningIn;

  /// Edit mode: the list does not exist, or belongs to another user (the
  /// backend answers `404` for both). Not a failure: nothing to retry.
  const factory ReadingListEditorState.notFound() = _NotFound;

  /// Edit mode: the list could not be read. `McBloc` reports it to
  /// monitoring (D-16).
  @Implements<McFailureState>()
  const factory ReadingListEditorState.loadFailed(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _LoadFailed;

  /// The wizard: every step's values, the current step, and the save's
  /// status (running, failed with an `ApiFailure`). [existing] is true in
  /// edit mode.
  const factory ReadingListEditorState.editing(
    WizardState<ReadingListId> wizard, {
    required bool existing,
  }) = _Editing;

  /// The session the editor belongs to ended (a sign-out, or another user
  /// signed in). Nothing more is written; the user can only close the
  /// editor (T-0048-AC6).
  const factory ReadingListEditorState.sessionEnded() = _SessionEnded;
}
