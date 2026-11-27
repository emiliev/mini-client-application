part of 'appearance_bloc.dart';

/// The appearance settings' state (Tide's shape, R16).
@Freezed(copyWith: false)
sealed class AppearanceState with _$AppearanceState {
  /// Before the screen has read the appearance.
  const factory AppearanceState.loading() = _Loading;

  /// The preferences in use and how they stand against the account.
  /// [signingIn]: signed out, the app is signing someone in for this screen.
  const factory AppearanceState.ready({
    required AppearancePreferences preferences,
    required AppearanceSyncStatus sync,
    @Default(false) bool signingIn,
  }) = _Ready;

  /// The device could not keep the choice: it applies now, but would not
  /// survive a restart. The screen keeps every control (a change is never
  /// blocked) and shows a banner whose Retry saves again (review round).
  @Implements<McFailureState>()
  const factory AppearanceState.failure(
    AppearancePreferences preferences,
    StorageFailure error, {
    required AppearanceSyncStatus sync,
    @Default(false) bool signingIn,
    StackTrace? stackTrace,
  }) = _Failure;
}
