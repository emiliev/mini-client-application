part of 'featured_bloc.dart';

/// A section's state (Tide's shape, R16).
@Freezed(copyWith: false)
sealed class FeaturedState with _$FeaturedState {
  const factory FeaturedState.loading() = _Loading;

  const factory FeaturedState.ready(List<Product> products) = _Ready;

  const factory FeaturedState.empty() = _Empty;

  @Implements<McFailureState>()
  const factory FeaturedState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
