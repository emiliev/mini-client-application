part of 'cart_summary_bloc.dart';

/// The cart section's state (Tide's shape, R16): the four section cases,
/// plus the two a signed-out user sees.
@Freezed(copyWith: false)
sealed class CartSummaryState with _$CartSummaryState {
  const factory CartSummaryState.loading() = _Loading;

  const factory CartSummaryState.ready(CartSummary cart) = _Ready;

  /// Signed in, with nothing in the cart.
  const factory CartSummaryState.empty() = _Empty;

  @Implements<McFailureState>()
  const factory CartSummaryState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;

  /// Nobody is signed in: the summary is hidden and nothing is requested;
  /// the section offers to sign in.
  const factory CartSummaryState.signedOut() = _SignedOut;

  /// The app is signing someone in for this section (`requestSignIn()`).
  /// A static message, no spinner: it may wait for the user indefinitely
  /// (F-0048 §5.10).
  const factory CartSummaryState.signingIn() = _SigningIn;
}
