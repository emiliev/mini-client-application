part of 'comic_favourite_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16).
@freezed
sealed class ComicFavouriteState with _$ComicFavouriteState {
  /// Reading the flag (signed in only); the toggle waits.
  const factory ComicFavouriteState.loading() = _Loading;

  /// The toggle shows [favourite]. [saving] while a sign-in or a write is in
  /// flight; [favourite] is then already the value being written.
  const factory ComicFavouriteState.ready({
    required bool favourite,
    @Default(false) bool saving,
  }) = _Ready;

  /// The flag could not be read; the toggle shows "not a favourite" and an
  /// inline error. `McBloc` reports it to monitoring.
  @Implements<McFailureState>()
  const factory ComicFavouriteState.loadFailed(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _LoadFailed;

  /// A write failed: the toggle is back at [favourite], the value before the
  /// tap, with an inline error. `McBloc` reports it to monitoring.
  @Implements<McFailureState>()
  const factory ComicFavouriteState.saveFailed(
    ApiFailure error, {
    required bool favourite,
    StackTrace? stackTrace,
  }) = _SaveFailed;
}
