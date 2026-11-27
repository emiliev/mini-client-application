import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:characters_details/characters_details.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_session/mc_session.dart';

/// characters_details' way out of the feature: its intents become routes.
/// It holds the [RouterRef], not a router, and asks for the live router at
/// each call (T-0033), so after the app's router is replaced it still pushes
/// to the one on screen.
///
/// - A comic is the publishing group's, so it goes through `AppLocations`
///   (plan 01 §4.2): `/comics/:id`.
/// - Signing in is the app's business: until the sign-in feature exists, the
///   temporary fixture sheet that `app_core` shares between the wirings signs
///   a fixture user in (P-044). The same hook every other wiring uses, so
///   the T-0066 merge switches them all at once.
@LazySingleton(as: CharacterDetailsNavigator)
class CharacterDetailsNavigatorImpl implements CharacterDetailsNavigator {
  CharacterDetailsNavigatorImpl(this._routerRef, this._session, this._auth);

  final RouterRef _routerRef;
  final SessionReader _session;
  final AuthApi _auth;

  @override
  void openComic(ComicId id) {
    unawaited(_routerRef.router.push(AppLocations.comic(id.value)));
  }

  /// True at once when someone is signed in; otherwise the sheet's answer.
  /// False when there is no navigator to show it on.
  @override
  Future<bool> requestSignIn() => requestFixtureSignIn(
    routerRef: _routerRef,
    session: _session,
    auth: _auth,
    reason: 'to keep your favourites',
  );
}
