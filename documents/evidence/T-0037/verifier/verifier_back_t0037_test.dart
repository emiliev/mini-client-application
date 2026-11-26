// T-0037 Verifier e2e probe (copied into the prepared pub project only):
// home -> Characters (the list shows the back chevron) -> preview -> back to
// the list (chevron still there) -> one tap on the list's back -> home.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VE2E T-0037 the list has a back chevron and one tap goes home', (
    tester,
  ) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;
    startApp(app.main);
    await pumpUntil(tester, find.byKey(const Key('home.placeholder')), 'home');
    expect(find.byType(BackButton), findsNothing);
    await shot(binding, tester, 'v01_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first card');
    await letArtLoad(tester);
    expect(find.byType(BackButton), findsOneWidget, reason: 'list chevron');
    await shot(binding, tester, 'v02_list_with_back');

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
