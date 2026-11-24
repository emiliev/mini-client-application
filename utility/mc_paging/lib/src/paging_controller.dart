import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/src/page.dart';
import 'package:mc_paging/src/paged_state.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Loads one page. A thrown error is mapped with `ApiFailure.from`.
typedef PageFetcher<T> =
    Future<Result<Page<T>, ApiFailure>> Function(PageRequest request);

/// Drives a [PagedState] over a [PageFetcher]. A bloc owns one and forwards
/// `onState` to `emit`; it is a plain helper, not a mixin (cutoff-critical
/// kit).
///
/// Every request, the first page included, sets `isLoadingMore`. Only one
/// request runs at a time. A failure keeps the loaded items; `loadMore` then
/// waits for `retry`, which repeats only the failed request.
final class PagingController<T> {
  PagingController({
    required PageFetcher<T> fetcher,
    required this.onState,
    this.limit = 20,
  }) : _fetcher = fetcher,
       _state = PagedState<T>(request: PageRequest(offset: 0, limit: limit)) {
    assert(limit > 0, 'limit must be positive');
  }

  final PageFetcher<T> _fetcher;

  /// Called with every new state.
  final void Function(PagedState<T> state) onState;

  /// Items per request.
  final int limit;

  PagedState<T> _state;
  bool _inFlight = false;
  bool _disposed = false;

  /// Bumped by loadFirst, refresh and dispose, so an older response is
  /// dropped when it arrives.
  int _generation = 0;
  ({PageRequest request, bool replace})? _failed;

  PagedState<T> get state => _state;

  /// Starts over: clears the items and loads the first page.
  Future<void> loadFirst() {
    _generation++;
    _failed = null;
    _emit(PagedState<T>(request: PageRequest(offset: 0, limit: limit)));
    return _run(PageRequest(offset: 0, limit: limit), replace: true);
  }

  /// Reloads the first page but keeps the shown items until it arrives.
  Future<void> refresh() {
    _generation++;
    _failed = null;
    return _run(PageRequest(offset: 0, limit: limit), replace: true);
  }

  /// Loads the next page. Does nothing at the end, while a request is in
  /// flight, or after a failure (use [retry]).
  Future<void> loadMore() async {
    if (_state.hasReachedEnd || _inFlight || _state.failure != null) {
      return;
    }
    await _run(_state.request, replace: false);
  }

  /// Repeats the request that failed. Does nothing when nothing failed.
  Future<void> retry() async {
    final failed = _failed;
    if (failed == null || _inFlight) {
      return;
    }
    await _run(failed.request, replace: failed.replace);
  }

  /// Drops any response still on its way and stops emitting.
  void dispose() {
    _disposed = true;
    _generation++;
  }

  Future<void> _run(PageRequest request, {required bool replace}) async {
    final generation = _generation;
    _inFlight = true;
    _failed = null;
    _emit(_state.copyWith(isLoadingMore: true, failure: null));

    Result<Page<T>, ApiFailure> result;
    try {
      result = await _fetcher(request);
    } on Object catch (error) {
      result = failure(ApiFailure.from(error));
    }
    if (generation != _generation) {
      return;
    }
    _inFlight = false;

    result.fold(
      (page) {
        final items = replace ? page.results : [..._state.items, ...page.results];
        final nextOffset = request.offset + page.results.length;
        _emit(
          _state.copyWith(
            items: items,
            request: PageRequest(offset: nextOffset, limit: limit),
            hasReachedEnd: page.results.isEmpty || nextOffset >= page.total,
            isLoadingMore: false,
            failure: null,
            total: page.total,
          ),
        );
      },
      (error) {
        _failed = (request: request, replace: replace);
        _emit(_state.copyWith(isLoadingMore: false, failure: error));
      },
    );
  }

  void _emit(PagedState<T> next) {
    _state = next;
    if (!_disposed) {
      onState(next);
    }
  }
}
