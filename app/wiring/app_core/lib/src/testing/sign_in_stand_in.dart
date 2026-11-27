import 'package:app_core/src/router/flow_results.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Keys of the stand-in sign-in screen, for tests.
const standInSignInKey = Key('app_core.stand_in.sign_in');
const standInSignInConfirmKey = Key('app_core.stand_in.sign_in.confirm');
const standInSignInNotNowKey = Key('app_core.stand_in.sign_in.not_now');

/// What the stand-in screen says it was opened for: its `reason` query
/// parameter, as a line of text a test can look for.
String standInSignInText(String? reason) => 'stand-in sign-in for $reason';

/// A stand-in for the real sign-in route (`/auth/sign-in`, account_wiring) in
/// a wiring's test, where only that wiring's routes exist (a wiring never
/// imports another). It is a result route like the real one
/// (`FlowResultRoute<bool>`), so `AppFlows.signIn` and `requestAppSignIn`
/// work on it as they do in the app.
///
/// The screen shows [standInSignInText] of the link's `reason`. "Sign in"
/// completes with what [signIn] answers (true when none is given), "Not now"
/// with false.
GoRoute standInSignInRoute({Future<bool> Function()? signIn}) => GoRoute(
  path: '/auth/sign-in',
  builder: (context, state) => FlowResultRoute<bool>(
    extra: state.extra,
    builder: (complete) => Scaffold(
      key: standInSignInKey,
      body: Column(
        children: [
          Text(standInSignInText(state.uri.queryParameters['reason'])),
          TextButton(
            key: standInSignInConfirmKey,
            onPressed: () async => complete(await signIn?.call() ?? true),
            child: const Text('Sign in'),
          ),
          TextButton(
            key: standInSignInNotNowKey,
            onPressed: () => complete(false),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  ),
);
