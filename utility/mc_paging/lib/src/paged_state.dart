import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/src/page.dart';

part 'paged_state.freezed.dart';

/// What a paged list shows. No JSON, so a bare `@freezed` is right (R30
/// concerns models with JSON only).
@freezed
abstract class PagedState<T> with _$PagedState<T> {
  const factory PagedState({
    /// Every item loaded so far, in order.
    @Default(<Never>[]) List<T> items,

    /// The request the next page load uses.
    @Default(PageRequest(offset: 0, limit: 20)) PageRequest request,

    /// No more pages: [items] holds everything.
    @Default(false) bool hasReachedEnd,

    /// A request is in flight, the first page included.
    @Default(false) bool isLoadingMore,

    /// Why the last request failed. [items] keeps what was loaded before.
    ApiFailure? failure,

    /// The backend's count of all matching items, once known.
    int? total,
  }) = _PagedState<T>;
}
