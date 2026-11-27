import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_session/mc_session.dart';
import 'package:trivia_quiz/trivia_quiz.dart';

/// trivia_quiz's way out of the feature: its intents become routes. It holds
/// the [RouterRef], not a router, and asks for the live router at each call
/// (T-0033).
///
/// - A comic is the publishing group's, so it goes through `AppLocations`
///   (plan 01 §4.2), as a push: Back returns to the results.
/// - Signing in is the app's business: `requestAppSignIn` (app_core) opens the
///   sign-in screen (T-0066).
@LazySingleton(as: TriviaQuizNavigator)
class TriviaQuizNavigatorImpl implements TriviaQuizNavigator {
  TriviaQuizNavigatorImpl(this._routerRef, this._session);

  final RouterRef _routerRef;
  final SessionReader _session;

  @override
  void openComic(ComicId id) {
    unawaited(_routerRef.router.push(AppLocations.comic(id.value)));
  }

  /// True at once when someone is signed in; otherwise the sign-in screen's
  /// answer (true only once a session exists). False when there is no
  /// navigator to show it on.
  @override
  Future<bool> requestSignIn() => requestAppSignIn(
    routerRef: _routerRef,
    session: _session,
    purpose: SignInPurpose.triviaResults,
  );
}
