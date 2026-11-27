part of 'banners_bloc.dart';

/// A section's state (Tide's shape: private cases read with `state.when`,
/// R16). `copyWith` is off: the bloc emits whole states.
@Freezed(copyWith: false)
sealed class BannersState with _$BannersState {
  /// The banners are on their way: the section shows its skeleton.
  const factory BannersState.loading() = _Loading;

  const factory BannersState.ready(List<StoreBanner> banners) = _Ready;

  /// The store has no banners right now.
  const factory BannersState.empty() = _Empty;

  /// The banners could not be loaded: the section's own error card with
  /// Retry. `McBloc` reports it to monitoring (D-16).
  @Implements<McFailureState>()
  const factory BannersState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
