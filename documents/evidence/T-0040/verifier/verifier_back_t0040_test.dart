// T-0040 Verifier e2e probe (copied into the prepared pub project only):
// home -> Characters: the list's bar is a McAppBar whose leading is the flow
// back chevron -> preview (also a McAppBar) -> back to the list -> one tap on
// the list's back -> home.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

// By type name, so the app package needs no new dependency for this probe.
Finder _byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VE2E T-0040 the list bar is McAppBar with the flow back; one '
      'tap goes home', (tester) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;
    startApp(app.main);
    await pumpUntil(tester, find.byKey(const Key('home.placeholder')), 'home');
    expect(find.byType(BackButton), findsNothing);
    expect(_byTypeName('McAppBar'), findsNothing, reason: 'home is not ours');
    await shot(binding, tester, 'v01_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first card');
    await letArtLoad(tester);
    expect(_byTypeName('McAppBar'), findsOneWidget);
    expect(
      find.descendant(
        of: _byTypeName('McAppBar'),
        matching: _byTypeName('McFlowBackButton'),
      ),
      findsOneWidget,
      reason: 'the flow back sits in the McAppBar leading',
    );
    expect(find.byType(BackButton), findsOneWidget, reason: 'list chevron');
    expect(
      find.descendant(
        of: _byTypeName('McAppBar'),
        matching: find.text('Characters'),
      ),
      findsOneWidget,
    );
    await shot(binding, tester, 'v02_list_mc_app_bar');

    await tester.tap(find.text(first.name));
    await pumpUntil(tester, find.text('See full profile'), 'the preview');
    expect(find.byType(BackButton), findsOneWidget, reason: 'one onstage');
    await shot(binding, tester, 'v03_preview');

    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.byKey(charactersGridKey), 'the list again');
    expect(find.text('See full profile'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget, reason: 'chevron kept');
    await shot(binding, tester, 'v04_list_after_preview');

    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.byKey(const Key('home.placeholder')), 'home');
    expect(find.byKey(charactersGridKey), findsNothing, reason: 'one tap');
    expect(find.byType(BackButton), findsNothing);
    await shot(binding, tester, 'v05_home_again');
  });
}
