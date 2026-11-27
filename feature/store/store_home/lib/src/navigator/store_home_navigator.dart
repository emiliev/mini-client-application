import 'package:store_home/src/domain/model/comic_id.dart';

/// What store_home needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/commerce_wiring` (T-0056). Only blocs call it.
///
/// Four of the DB archetype's six methods (plan 01 §6.1). Deferred until
/// their features exist: `openCheckout()` (with the checkout feature, F078)
/// and `openPromo(code)` (promo entry). A category of the store is not a
/// navigator call: it is a page of this flow.
abstract interface class StoreHomeNavigator {
  /// A product, a deal or a banner that targets a comic: hands over to the
  /// comic's page.
  void openComic(ComicId id);

  /// A banner that targets a search: hands over to the search, starting with
  /// [query].
  void openSearch(String query);

  /// The cart summary: hands over to the cart (a placeholder until the cart
  /// feature exists).
  void openCart();

  /// The cart needs a signed-in user. Completes with true once someone
  /// signed in, false when the user backed out. The feature does not know
  /// how signing in works; the app decides.
  Future<bool> requestSignIn();
}
