part of 'cart_summary_bloc.dart';

/// What the cart section asks for (Tide's sealed events).
sealed class CartSummaryEvent {
  const CartSummaryEvent();

  /// The first load (the bloc adds it itself).
  const factory CartSummaryEvent.load() = _Load;

  /// Retry after a failure: loads this section again, and only this one.
  const factory CartSummaryEvent.retry() = _Retry;

  /// Pull to refresh; [done] completes when the answer arrived (at once
  /// while signed out: there is nothing to reload).
  const factory CartSummaryEvent.refresh(Completer<void> done) = _Refresh;

  /// Signed out, "Sign in to see your cart" was tapped.
  const factory CartSummaryEvent.signIn() = _SignIn;

  /// The summary was tapped: the cart opens.
  const factory CartSummaryEvent.open() = _Open;
}

final class _Load extends CartSummaryEvent {
  const _Load();
}

final class _Retry extends CartSummaryEvent {
  const _Retry();
}

final class _Refresh extends CartSummaryEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _SignIn extends CartSummaryEvent {
  const _SignIn();
}

final class _Open extends CartSummaryEvent {
  const _Open();
}

/// Internal: `SessionReader.authState` changed (a sign-in, a sign-out or a
/// user switch, here or anywhere else in the app).
final class _SessionChanged extends CartSummaryEvent {
  const _SessionChanged();
}
