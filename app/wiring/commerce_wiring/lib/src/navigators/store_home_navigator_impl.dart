import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:commerce_wiring/src/routes/store_routes.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_session/mc_session.dart';
import 'package:store_home/store_home.dart';

/// store_home's way out of the feature: its intents become routes. It holds
/// the [RouterRef], not a router, and asks for the live router at each call
/// (T-0033), so after the app's router is replaced it still pushes to the
/// one on screen.
///
/// - A comic and the search are other groups' (publishing, discovery), so
///   they go through `AppLocations` (plan 01 §4.2). Each is a push, so Back
///   returns to the store.
/// - The cart is this group's, so it uses the typed route.
/// - Signing in is the app's business: `requestAppSignIn` (app_core) opens the
///   sign-in screen (T-0066).
@LazySingleton(as: StoreHomeNavigator)
class StoreHomeNavigatorImpl implements StoreHomeNavigator {
  StoreHomeNavigatorImpl(this._routerRef, this._session);

  final RouterRef _routerRef;
  final SessionReader _session;

  @override
  void openComic(ComicId id) {
    unawaited(_routerRef.router.push(AppLocations.comic(id.value)));
  }

  @override
  void openSearch(String query) {
    unawaited(_routerRef.router.push(AppLocations.search(query)));
  }

  @override
  void openCart() {
    unawaited(_routerRef.router.push(const StoreCartRoute().location));
  }

  /// True at once when someone is signed in; otherwise the sign-in screen's
  /// answer (true only once a session exists). False when there is no
  /// navigator to show it on.
  @override
  Future<bool> requestSignIn() => requestAppSignIn(
    routerRef: _routerRef,
    session: _session,
    purpose: SignInPurpose.cart,
  );
}
