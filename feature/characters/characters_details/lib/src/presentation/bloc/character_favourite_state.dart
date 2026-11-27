part of 'character_favourite_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16).
@freezed
sealed class CharacterFavouriteState with _$CharacterFavouriteState {
  /// Reading the flag (signed in only); the toggle waits.
  const factory CharacterFavouriteState.loading() = _Loading;

  /// The app is signing someone in for this tap (`requestSignIn()`); the
  /// toggle waits and still offers to add.
  const factory CharacterFavouriteState.signingIn() = _SigningIn;

  /// The toggle shows [favourite]. [saving] while a write is in flight;
  /// [favourite] is then already the value being written (optimistic).
  const factory CharacterFavouriteState.ready({
    required bool favourite,
    @Default(false) bool saving,
  }) = _Ready;

  /// The flag could not be read; the toggle shows "not a favourite" and an
  /// inline error. `McBloc` reports it to monitoring.
  @Implements<McFailureState>()
  const factory CharacterFavouriteState.loadFailed(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _LoadFailed;

  /// A write failed: the toggle is back at [favourite], the value before the
  /// tap, with an inline error. `McBloc` reports it to monitoring.
  @Implements<McFailureState>()
  const factory CharacterFavouriteState.saveFailed(
    ApiFailure error, {
    required bool favourite,
    StackTrace? stackTrace,
  }) = _SaveFailed;
}
