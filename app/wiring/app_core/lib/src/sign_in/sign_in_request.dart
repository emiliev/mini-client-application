import 'package:app_core/src/router/flow_results.dart';
import 'package:app_core/src/router/router_ref.dart';
import 'package:mc_session/mc_session.dart';

/// What signing in is for, so the sign-in screen can say so. The names are
/// the codes of the `reason` query parameter of `/auth/sign-in`, and equal
/// the sign-in feature's `SignInReason` (account_wiring tests it).
enum SignInPurpose {
  favourites,
  readingLists,
  cart,
  triviaResults,
  appearanceSync,
}

/// The app's answer to a feature's `requestSignIn()` (T-0066, which replaced
/// the fixture sheet, P-044): every wiring whose navigator needs one calls
/// it with its own [purpose], or an explicit null when signing in has no reason of its
/// own (the settings index, T-0070): the screen then says nothing about it.
///
/// True at once when someone is signed in. Otherwise it opens the sign-in
/// screen on the router (`AppFlows.signIn`, a result route) and answers true
/// **only when a session exists afterwards**: false when the user chose "Not
/// now", left by Back, or the screen could not be shown (no router navigator
/// yet, as before the first frame).
///
/// Both must hold: the screen ended as signed in **and** the session exists,
/// so a session that ended in between (signed out elsewhere) is no answer
/// of true either.
Future<bool> requestAppSignIn({
  required RouterRef routerRef,
  required SessionReader session,
  required SignInPurpose? purpose,
}) async {
  if (session.isSignedIn) {
    return true;
  }
  final router = routerRef.router;
  if (router.routerDelegate.navigatorKey.currentContext == null) {
    return false;
  }
  final signedIn = await AppFlows.signIn(router, reason: purpose);
  return signedIn && session.isSignedIn;
}
