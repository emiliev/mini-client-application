import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:comics_details/comics_details.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_session/mc_session.dart';
import 'package:publishing_wiring/src/routes/creators_routes.dart';
import 'package:publishing_wiring/src/sign_in/fixture_sign_in_sheet.dart';

/// comics_details' way out of the feature: its intents become routes.
/// It holds the [RouterRef], not a router, and asks for the live router at
/// each call (T-0033), so after the app's router is replaced it still pushes
/// to the one on screen.
///
/// - A character is another group's (universe), so it goes through
///   `AppLocations` (plan 01 §4.2): today the characters placeholder route.
/// - A creator is this group's, so it uses the typed route.
/// - Signing in is the app's business: until the sign-in feature exists, a
///   temporary sheet in this wiring signs a fixture user in (P-044).
@LazySingleton(as: ComicsDetailsNavigator)
class ComicsDetailsNavigatorImpl implements ComicsDetailsNavigator {
  ComicsDetailsNavigatorImpl(this._routerRef, this._session, this._auth);

  final RouterRef _routerRef;
  final SessionReader _session;
  final AuthApi _auth;

  @override
  void openCharacter(CharacterId id) {
    unawaited(_routerRef.router.push(AppLocations.character(id.value)));
  }

  @override
  void openCreator(CreatorId id) {
    unawaited(
      _routerRef.router.push(CreatorDetailsRoute(id: id.value).location),
    );
  }

  /// True at once when someone is signed in; otherwise the sheet's answer.
  /// False when there is no navigator to show it on.
  @override
  Future<bool> requestSignIn() async {
    if (_session.isSignedIn) {
      return true;
    }
    final context =
        _routerRef.router.routerDelegate.navigatorKey.currentContext;
    if (context == null) {
      return false;
    }
    return showFixtureSignInSheet(context, _auth);
  }
}
