part of 'categories_bloc.dart';

/// What the categories section asks for (Tide's sealed events).
sealed class CategoriesEvent {
  const CategoriesEvent();

  /// The first load (the bloc adds it itself).
  const factory CategoriesEvent.load() = _Load;

  /// Retry after a failure: loads this section again, and only this one.
  const factory CategoriesEvent.retry() = _Retry;

  /// Pull to refresh; [done] completes when the answer arrived.
  const factory CategoriesEvent.refresh(Completer<void> done) = _Refresh;

  /// A category was tapped: its page opens inside the flow.
  const factory CategoriesEvent.open(StoreCategory category) = _Open;
}

final class _Load extends CategoriesEvent {
  const _Load();
}

final class _Retry extends CategoriesEvent {
  const _Retry();
}

final class _Refresh extends CategoriesEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends CategoriesEvent {
  const _Open(this.category);

  final StoreCategory category;
}
