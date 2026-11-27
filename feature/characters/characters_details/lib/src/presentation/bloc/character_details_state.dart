part of 'character_details_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16); freezed 4
/// adds only `sealed`.
@freezed
sealed class CharacterDetailsState with _$CharacterDetailsState {
  /// The character is on its way.
  const factory CharacterDetailsState.loading() = _Loading;

  /// The character and the comics it appears in (possibly none).
  const factory CharacterDetailsState.success(
    Character character,
    List<ComicSummary> comics,
  ) = _Success;

  /// No character has this id (`404`). Not a failure: nothing to retry or
  /// report.
  const factory CharacterDetailsState.notFound() = _NotFound;

  /// The character or its comics could not be loaded. `McBloc` reports it to
  /// monitoring (D-16).
  @Implements<McFailureState>()
  const factory CharacterDetailsState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
