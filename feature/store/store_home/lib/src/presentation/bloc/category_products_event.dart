part of 'category_products_bloc.dart';

/// What the category page asks for (Tide's sealed events).
sealed class CategoryProductsEvent {
  const CategoryProductsEvent();

  /// Starts over with the first page (the bloc adds it itself).
  const factory CategoryProductsEvent.load() = _Load;

  /// The grid scrolled past its load-more threshold.
  const factory CategoryProductsEvent.loadMore() = _LoadMore;

  /// Repeats the request that failed (the first page or a later one).
  const factory CategoryProductsEvent.retry() = _Retry;

  /// Pull to refresh: reloads the first page and keeps the items meanwhile.
  const factory CategoryProductsEvent.refresh(Completer<void> done) =
      _Refresh;

  /// A product was tapped: its comic opens.
  const factory CategoryProductsEvent.open(Product product) = _Open;
}

final class _Load extends CategoryProductsEvent {
  const _Load();
}

final class _LoadMore extends CategoryProductsEvent {
  const _LoadMore();
}

final class _Retry extends CategoryProductsEvent {
  const _Retry();
}

final class _Refresh extends CategoryProductsEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends CategoryProductsEvent {
  const _Open(this.product);

  final Product product;
}

/// Internal: the paging controller produced a new state.
final class _PageChanged extends CategoryProductsEvent {
  const _PageChanged(this.page);

  final PagedState<Product> page;
}

/// Internal: the opener did not know the category's name; look it up.
final class _ResolveName extends CategoryProductsEvent {
  const _ResolveName();
}
