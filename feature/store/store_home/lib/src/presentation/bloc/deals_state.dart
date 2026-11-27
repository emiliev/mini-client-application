part of 'deals_bloc.dart';

/// A section's state (Tide's shape, R16).
@Freezed(copyWith: false)
sealed class DealsState with _$DealsState {
  const factory DealsState.loading() = _Loading;

  /// The deals, and the time their "ends in" is counted from (the injected
  /// clock, read when they arrived).
  const factory DealsState.ready(List<Deal> deals, DateTime now) = _Ready;

  const factory DealsState.empty() = _Empty;

  @Implements<McFailureState>()
  const factory DealsState.failure(ApiFailure error, {StackTrace? stackTrace}) =
      _Failure;
}
