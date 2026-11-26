part of 'comic_details_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16); freezed 4
/// adds only `sealed`.
@freezed
sealed class ComicDetailsState with _$ComicDetailsState {
  /// The comic is on its way.
  const factory ComicDetailsState.loading() = _Loading;

  /// The comic, its credits and its cast.
  const factory ComicDetailsState.success(Comic comic) = _Success;

  /// No comic has this id (`404`). Not a failure: nothing to retry or report.
  const factory ComicDetailsState.notFound() = _NotFound;

  /// The comic could not be loaded. `McBloc` reports it to monitoring (D-16).
  @Implements<McFailureState>()
  const factory ComicDetailsState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
