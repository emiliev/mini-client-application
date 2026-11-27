part of 'categories_bloc.dart';

/// A section's state (Tide's shape, R16).
@Freezed(copyWith: false)
sealed class CategoriesState with _$CategoriesState {
  const factory CategoriesState.loading() = _Loading;

  const factory CategoriesState.ready(List<StoreCategory> categories) = _Ready;

  const factory CategoriesState.empty() = _Empty;

  @Implements<McFailureState>()
  const factory CategoriesState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
