import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:store_home/src/domain/model/category_id.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/domain/repository/store_home_repository.dart';
import 'package:store_home/src/flow/store_home_flow_state.dart';
import 'package:store_home/src/navigator/store_home_navigator.dart';
import 'package:store_home/src/presentation/bloc/store_section_bloc.dart'
    show openGuard;

part 'category_products_bloc.freezed.dart';
part 'category_products_event.dart';
part 'category_products_state.dart';

/// Products per request: 20, the contract's default page.
const int categoryPageSize = 20;

/// The category page's bloc: one category's products through a
/// [PagingController] (offset and limit: load, load more at the end of the
/// list, refresh, retry), and a tapped product's comic handed over to the
/// app. The category is the one the flow shows (opened above the store home,
/// or the flow's only page for `/store/categories/:id`).
///
/// When the opener did not know the category's name (a banner, a deep link),
/// it is looked up once in `GET v1/store/categories` and written into the
/// flow state, which titles the page; if that fails, the page keeps its
/// generic title.
@injectable
final class CategoryProductsBloc
    extends McBloc<CategoryProductsEvent, CategoryProductsState> {
  CategoryProductsBloc(
    this._repository,
    this._flow,
    this._navigator,
    this._tracker,
    Monitoring monitoring,
  ) : _category = (_flow.state.category ?? _flow.state.rootCategory)!,
      super(const CategoryProductsState.loading(), monitoring: monitoring) {
    _paging = PagingController<Product>(
      fetcher: (request) =>
          _repository.fetchCategoryPage(_category.id, request),
      // The controller reports outside any handler; an event brings each
      // state back into the bloc, so only a handler emits.
      onState: (page) => add(_PageChanged(page)),
      limit: categoryPageSize,
    );
    on<CategoryProductsEvent>(_onEvent);
    add(const CategoryProductsEvent.load());
    if (_category.name == null) {
      add(const _ResolveName());
    }
  }

  final StoreHomeRepository _repository;
  final FeatureFlowController<StoreHomeFlowState> _flow;
  final StoreHomeNavigator _navigator;
  final AnalyticsTracker _tracker;
  final OpenCategory _category;
  late final PagingController<Product> _paging;
  Timer? _openGuard;
  int? _openTarget;

  Future<void> _onEvent(
    CategoryProductsEvent event,
    Emitter<CategoryProductsState> emit,
  ) async {
    switch (event) {
      case _Load():
        await _paging.loadFirst();
      case _LoadMore():
        await _paging.loadMore();
      case _Retry():
        await _paging.retry();
      case _Refresh(:final done):
        try {
          await _paging.refresh();
        } finally {
          done.complete();
        }
      case _Open(:final product):
        if (_startOpenGuard(product.id.value)) {
          _tracker.itemTapped(
            StoreSection.categoryProducts,
            StoreItemKind.comic,
            '${product.id.value}',
          );
          _navigator.openComic(product.id);
        }
      case _PageChanged(:final page):
        emit(_toState(page));
      case _ResolveName():
        await _resolveName();
    }
  }

  /// No items yet: an unknown category is "not found", another failure the
  /// full-page error, anything else still loading. With items, or at the
  /// end of an empty category, the grid shows the page (its footer carries a
  /// later page's failure, with Retry).
  static CategoryProductsState _toState(PagedState<Product> page) =>
      switch (page) {
        PagedState(items: [], failure: ApiNotFound()) =>
          const CategoryProductsState.notFound(),
        PagedState(items: [], failure: final failure?) =>
          CategoryProductsState.failure(failure),
        PagedState(items: [], hasReachedEnd: false) =>
          const CategoryProductsState.loading(),
        _ => CategoryProductsState.success(page),
      };

  Future<void> _resolveName() async {
    final result = await _repository.fetchCategories();
    if (isClosed) {
      return;
    }
    final id = _category.id;
    final name = result
        .getOrElse(() => const [])
        .where((c) => c.id == id)
        .map((c) => c.name)
        .firstOrNull;
    if (name != null) {
      _flow.update((s) => _named(s, id, name));
    }
  }

  static StoreHomeFlowState _named(
    StoreHomeFlowState s,
    CategoryId id,
    String name,
  ) => switch (s) {
    StoreHomeFlowState(category: OpenCategory(id: final open))
        when open == id =>
      s.copyWith(
        category: OpenCategory(id: id, name: name),
      ),
    StoreHomeFlowState(rootCategory: OpenCategory(id: final root))
        when root == id =>
      s.copyWith(
        rootCategory: OpenCategory(id: id, name: name),
      ),
    // The page left meanwhile: nothing to title.
    _ => s,
  };

  bool _startOpenGuard(int target) {
    if ((_openGuard?.isActive ?? false) && _openTarget == target) {
      return false;
    }
    _openGuard?.cancel();
    _openGuard = Timer(openGuard, () {});
    _openTarget = target;
    return true;
  }

  @override
  Future<void> close() {
    _openGuard?.cancel();
    _paging.dispose();
    return super.close();
  }
}
