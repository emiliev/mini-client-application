import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_home/settings_home.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockSettingsHomeNavigator extends Mock implements SettingsHomeNavigator {}

/// What the running test's navigator mock was asked, and what is waiting for
/// an answer.
class _Calls {
  int signIns = 0;
  int signOuts = 0;
  int appearances = 0;
  final List<Completer<bool>> pendingSignIns = [];
  final List<Completer<void>> pendingSignOuts = [];
}

final Expando<MockSettingsHomeNavigator> _navigators = Expando(
  'settings_home navigator',
);
final Expando<_Calls> _callsOf = Expando('settings_home calls');

_Calls get _calls => _callsOf[McTestSession.current] ??= _Calls();

/// The running test's navigator mock: one per test, keyed by its session.
/// `requestSignIn` and `signOut` answer with pending futures that a later
/// step settles (`signing in succeeds as`, `the app signs the user out`), so
/// a scenario can look at the page while the feature waits for the app.
MockSettingsHomeNavigator settingsNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

MockSettingsHomeNavigator _newNavigator() {
  final navigator = MockSettingsHomeNavigator();
  when(navigator.requestSignIn).thenAnswer((_) {
    final calls = _calls..signIns += 1;
    final answer = Completer<bool>();
    calls.pendingSignIns.add(answer);
    return answer.future;
  });
  when(navigator.signOut).thenAnswer((_) {
    final calls = _calls..signOuts += 1;
    final answer = Completer<void>();
    calls.pendingSignOuts.add(answer);
    return answer.future;
  });
  when(navigator.openAppearance).thenAnswer((_) => _calls.appearances += 1);
  return navigator;
}

/// The sign-ins the feature asked for and nobody answered yet, oldest first.
List<Completer<bool>> pendingSignIns() => _calls.pendingSignIns;

/// The sign-outs the feature asked for and nobody answered yet, oldest first.
List<Completer<void>> pendingSignOuts() => _calls.pendingSignOuts;

/// How many times the feature asked the app to sign in, in all.
int signInRequests() => _calls.signIns;

/// How many times the feature asked the app to sign out, in all.
int signOutRequests() => _calls.signOuts;

/// How many times the feature asked to open the appearance settings.
int appearanceRequests() => _calls.appearances;

/// The test root, once per test (unless an earlier step such as `I am
/// signed in as` made it).
Future<void> ensureSettingsContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
}

/// The flow as the app builds it, over the session's navigator mock.
Widget settingsFlowUnderTest() =>
    SettingsHomeFlow(navigator: settingsNavigator());

/// The app-wide appearance the Appearance row shows (the root container's).
AppearanceSettings appearance() => diContainer<AppearanceSettings>();

// --- keys (plan 05 §3.5: steps find by key, never by a feature widget type)

const settingsBodyKey = ValueKey<String>('settings_home.body');

/// The key of a row or button of the page: `account`, `sign_in`, `sign_out`,
/// `appearance`, `about.version`, `about.seed`.
ValueKey<String> rowKey(String name) => ValueKey('settings_home.$name');

// --- fixture facts (mc_fixtures_identity CONTRACT.md) ---------------------

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// Signs [email] in through the real `AuthApi` of the test container
/// (inside `runAsync`: the session saves to a real file, F-0038).
Future<void> signIn(WidgetTester tester, String email) async {
  final user = fixtureUser(email);
  final result = await tester.runAsync(
    () => diContainer<AuthApi>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
}

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`),
/// and by the package's other test files in their `setUpAll`.
void bddSetUpAll() {
  identityFixtureSets.forEach(McFixtureSets.register);
}
