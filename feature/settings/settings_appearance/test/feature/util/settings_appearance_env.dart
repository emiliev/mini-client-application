import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockSettingsAppearanceNavigator extends Mock
    implements SettingsAppearanceNavigator {}

final Expando<MockSettingsAppearanceNavigator> _navigators = Expando(
  'settings_appearance navigator',
);
final Expando<List<Completer<bool>>> _signIns = Expando(
  'settings_appearance sign-ins',
);

/// The running test's navigator mock: one per test, keyed by its session.
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`), so a scenario can
/// look at the page while the feature waits for the app.
MockSettingsAppearanceNavigator settingsNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

MockSettingsAppearanceNavigator _newNavigator() {
  final navigator = MockSettingsAppearanceNavigator();
  when(navigator.requestSignIn).thenAnswer((_) {
    final session = McTestSession.current;
    _asked[session] = (_asked[session] ?? 0) + 1;
    final answer = Completer<bool>();
    pendingSignIns().add(answer);
    return answer.future;
  });
  return navigator;
}

/// The sign-ins the feature asked for and nobody answered yet, oldest first.
List<Completer<bool>> pendingSignIns() =>
    _signIns[McTestSession.current] ??= [];

/// How many times the feature asked the app to sign in, in all (mocktail's
/// `verify` forgets what it already verified, F-0056 §7 fact 4).
int signInRequests() => _asked[McTestSession.current] ?? 0;

final Expando<int> _asked = Expando('settings_appearance sign-in count');

/// The test root, once per test (unless an earlier step such as `I am
/// signed in as` made it). The package's `setUpAll` makes its appearance
/// follow the account (`McTestContainer.appearanceFollowsAccount`).
Future<void> ensureSettingsContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
}

/// The flow as the app builds it, over the session's navigator mock.
Widget settingsFlowUnderTest() =>
    SettingsAppearanceFlow(navigator: settingsNavigator());

/// The app-wide appearance the screen changes (the root container's).
AppearanceSettings appearance() => diContainer<AppearanceSettings>();

// --- keys (plan 05 §3.5: steps find by key, never by a feature widget type)

const appearanceBodyKey = ValueKey<String>('settings_appearance.body');
const aboutBodyKey = ValueKey<String>('settings_appearance_about.body');
const syncStatusKey = ValueKey<String>('settings_appearance.sync');
const reduceMotionKey = ValueKey<String>('settings_appearance.reduce_motion');

ValueKey<String> themeModeKey(String wire) =>
    ValueKey('settings_appearance.theme.$wire');
ValueKey<String> densityKey(String wire) =>
    ValueKey('settings_appearance.density.$wire');

/// The segmented control that holds the segment keyed [segment].
McSegmented segmentedOf(WidgetTester tester, Key segment) {
  final control = find.ancestor(
    of: find.byKey(segment),
    matching: find.byType(McSegmented),
  );
  expect(control, findsOneWidget, reason: 'the control of $segment');
  return tester.widget<McSegmented>(control);
}

/// The label of the selected segment of the control that holds [segment].
String selectedLabel(WidgetTester tester, Key segment) {
  final control = segmentedOf(tester, segment);
  return control.segments[control.selectedIndex].label;
}

/// Taps the segment labelled [label] of the control that holds [segment].
Future<void> tapSegment(WidgetTester tester, Key segment, String label) async {
  final control = find.ancestor(
    of: find.byKey(segment),
    matching: find.byType(McSegmented),
  );
  await scrollSettingsTo(tester, control);
  final target = find.descendant(of: control, matching: find.text(label));
  expect(target.hitTestable(), findsOneWidget, reason: 'the "$label" segment');
  await tester.tap(target.hitTestable());
  await mcSettle(tester);
}

/// Scrolls the settings until [finder] is on screen.
Future<void> scrollSettingsTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find
        .descendant(
          of: find.byKey(appearanceBodyKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

// --- fixture facts (mc_fixtures_identity CONTRACT.md) ---------------------

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// [email]'s account copy of the preferences, read straight from the backend
/// engine with a minted token (the harness records nothing).
Future<Map<String, Object?>> accountOf(
  WidgetTester tester,
  String email,
) async {
  final user = fixtureUser(email);
  final response = await tester.runAsync(
    () => McTestSession.current.backend.backend.createDio().get<Object?>(
      'v1/me/preferences',
      options: Options(
        headers: {'Authorization': 'Bearer ${mintAccessToken(user.id, 1)}'},
      ),
    ),
  );
  final data = response?.data;
  return (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;
}

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
  // The screen is about the appearance and its sync: the appearance follows
  // the signed-in user's account here, as in the app.
  McTestContainer.appearanceFollowsAccount = true;
  identityFixtureSets.forEach(McFixtureSets.register);
}
