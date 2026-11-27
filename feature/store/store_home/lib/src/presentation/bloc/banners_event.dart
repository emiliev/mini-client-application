part of 'banners_bloc.dart';

/// What the banners section asks for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories.
sealed class BannersEvent {
  const BannersEvent();

  /// The first load: the page adds it once it is shown (F-0056 §1).
  const factory BannersEvent.load() = _Load;

  /// Retry after a failure: loads this section again, and only this one.
  const factory BannersEvent.retry() = _Retry;

  /// Pull to refresh: reloads and keeps the banners meanwhile. [done]
  /// completes when the answer arrived, so the refresh control closes.
  const factory BannersEvent.refresh(Completer<void> done) = _Refresh;

  /// A banner was tapped.
  const factory BannersEvent.open(StoreBanner banner) = _Open;
}

final class _Load extends BannersEvent {
  const _Load();
}

final class _Retry extends BannersEvent {
  const _Retry();
}

final class _Refresh extends BannersEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends BannersEvent {
  const _Open(this.banner);

  final StoreBanner banner;
}
