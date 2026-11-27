part of 'featured_bloc.dart';

/// What the featured section asks for (Tide's sealed events).
sealed class FeaturedEvent {
  const FeaturedEvent();

  /// The first load: the page adds it once it is shown (F-0056 §1).
  const factory FeaturedEvent.load() = _Load;

  /// Retry after a failure: loads this section again, and only this one.
  const factory FeaturedEvent.retry() = _Retry;

  /// Pull to refresh; [done] completes when the answer arrived.
  const factory FeaturedEvent.refresh(Completer<void> done) = _Refresh;

  /// A product was tapped: its comic opens.
  const factory FeaturedEvent.open(Product product) = _Open;
}

final class _Load extends FeaturedEvent {
  const _Load();
}

final class _Retry extends FeaturedEvent {
  const _Retry();
}

final class _Refresh extends FeaturedEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends FeaturedEvent {
  const _Open(this.product);

  final Product product;
}
