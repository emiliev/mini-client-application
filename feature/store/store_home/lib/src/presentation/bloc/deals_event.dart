part of 'deals_bloc.dart';

/// What the deals section asks for (Tide's sealed events, private cases).
sealed class DealsEvent {
  const DealsEvent();

  /// The first load (the bloc adds it itself).
  const factory DealsEvent.load() = _Load;

  /// Retry after a failure: loads this section again, and only this one.
  const factory DealsEvent.retry() = _Retry;

  /// Pull to refresh; [done] completes when the answer arrived.
  const factory DealsEvent.refresh(Completer<void> done) = _Refresh;

  /// A deal was tapped: its comic opens.
  const factory DealsEvent.open(Deal deal) = _Open;
}

final class _Load extends DealsEvent {
  const _Load();
}

final class _Retry extends DealsEvent {
  const _Retry();
}

final class _Refresh extends DealsEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends DealsEvent {
  const _Open(this.deal);

  final Deal deal;
}
