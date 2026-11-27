part of 'category_products_bloc.dart';

/// Tide's state shape (R16). `copyWith` is off: freezed's deep copy of a
/// `PagedState` field would name `$PagedStateCopyWith` (F-0031 Part A
/// fact 2), and the bloc emits whole states.
@Freezed(copyWith: false)
sealed class CategoryProductsState with _$CategoryProductsState {
  /// The first page is on its way.
  const factory CategoryProductsState.loading() = _Loading;

  /// Something to show: products (perhaps loading or failing more), or a
  /// settled empty category.
  const factory CategoryProductsState.success(PagedState<Product> page) =
      _Success;

  /// No category has this id (`404`). Not a failure: nothing to retry.
  const factory CategoryProductsState.notFound() = _NotFound;

  /// The first page failed. `McBloc` reports it to monitoring (D-16).
  @Implements<McFailureState>()
  const factory CategoryProductsState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
