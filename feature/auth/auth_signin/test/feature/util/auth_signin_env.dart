import 'dart:async';

import 'package:auth_signin/auth_signin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// The app's side of the feature contract (plan 05 §3.5): it has no methods
/// yet, so a plain class does.
class SignInNavigatorUnderTest implements AuthSignInNavigator {}

final Expando<List<SignInResult>> _results = Expando(
  'auth_signin results',
);

/// Every result the flow completed with (`onComplete`), in order: the flow
/// result as the wiring would receive it.
List<SignInResult> signInResults() => _results[McTestSession.current] ??= [];

/// The test root, once per test: the production-shaped container (unless an
/// earlier step made it).
Future<void> ensureSignInContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
}

/// The accounts the app offers, from the fixture users (the app's wiring does
/// the same).
List<DemoAccount> demoAccounts() => [
  for (final user in fixtureUsers)
    DemoAccount(
      email: user.email,
      password: user.password,
      displayName: user.displayName,
    ),
];

/// The flow as the app builds it, with a result recorder in place of the
/// route's pop.
Widget signInFlowUnderTest({
  SignInReason? reason,
  List<DemoAccount> accounts = const [],
}) => AuthSignInFlow(
  navigator: SignInNavigatorUnderTest(),
  reason: reason,
  demoAccounts: accounts,
  onComplete: signInResults().add,
);

/// The feature's string keys (plan 05 §3.5: steps find by key, never by the
/// type of a feature widget). They mirror the feature's own constants.
const signInFormKey = ValueKey<String>('auth_signin.form');
const signInNotNowKey = ValueKey<String>('auth_signin.not_now');
const signInReasonKey = ValueKey<String>('auth_signin.reason');

/// The key of the demo-account button for [email].
ValueKey<String> demoAccountKey(String email) =>
    ValueKey<String>('auth_signin.demo.$email');

/// The text field labelled [label] (its `McTextField`'s `TextField`).
Finder textFieldLabelled(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField));

/// Replaces the text of the field labelled [label], as typing does, then
/// moves the focus away so the field reports it was touched.
Future<void> enterText(WidgetTester tester, String label, String text) async {
  final field = textFieldLabelled(label).hitTestable();
  expect(field, findsOneWidget, reason: 'one field labelled "$label"');
  await tester.enterText(field, text);
  await mcSettle(tester);
  FocusManager.instance.primaryFocus?.unfocus();
  await mcSettle(tester);
}

/// The field labelled [label] shows [text].
void expectFieldText(WidgetTester tester, String label, String text) {
  final field = textFieldLabelled(label);
  expect(field, findsOneWidget, reason: 'one field labelled "$label"');
  expect(tester.widget<TextField>(field).controller!.text, text);
}

/// [text] shows as the error of the field labelled [label].
void expectErrorUnder(WidgetTester tester, String label, String text) {
  final field = textFieldLabelled(label);
  expect(field, findsOneWidget, reason: 'one field labelled "$label"');
  final error = tester.widget<TextField>(field).decoration!.error;
  expect(error, isNotNull, reason: '"$label" shows an error');
  expect(
    find.descendant(of: find.byWidget(error!), matching: find.text(text)),
    findsOneWidget,
    reason: 'the error under "$label"',
  );
}

/// Ends a step that sends the sign-in: while a hold keeps the request on its
/// way, two frames are pumped (the spinner never settles); otherwise the
/// session's real file save runs to the end (a `testWidgets` body runs on fake
/// time, F-0038) and the screen settles.
Future<void> settleSignIn(WidgetTester tester) async {
  if (McTestSession.current.backend.hasHolds) {
    await tester.pump();
    await tester.pump();
    return;
  }
  // The request first (fake time), then the save (real time).
  await tester.pump(const Duration(milliseconds: 500));
  await mcFinishStorageIo(tester);
  await mcSettle(tester);
}

/// The fixture user with [email].
FixtureUser fixtureUser(String email) => fixtureUsers.firstWhere(
  (u) => u.email == email,
  orElse: () => throw ArgumentError.value(email, 'email', 'no fixture user'),
);

/// Asks the backend who is signed in, through the app's own `Dio` (with its
/// auth interceptor, which refreshes an expired access token and replays the
/// request): the answer's status. The request runs on the test's fake time,
/// and the session's real file save (the refreshed tokens) runs to the end,
/// as it does in the app.
Future<int?> askWhoIsSignedIn(WidgetTester tester) async {
  int? status;
  var answered = false;
  unawaited(
    diContainer<Dio>()
        .get<Object?>('/v1/me')
        .then(
          (response) => status = response.statusCode,
          onError: (Object e) =>
              status = e is DioException ? e.response?.statusCode : -1,
        )
        .whenComplete(() => answered = true),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await mcFinishStorageIo(tester);
  await mcSettle(tester);
  expect(answered, isTrue, reason: 'the request was answered');
  return status;
}

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  identityFixtureSets.forEach(McFixtureSets.register);
}
