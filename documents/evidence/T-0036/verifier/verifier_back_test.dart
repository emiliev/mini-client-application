import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

/// T-0036 Verifier (not committed to the branch; copied into the e2e scratch
/// project only): home -> Characters shows McFlowBackButton; a preview and
/// back keeps it; tapping it returns home.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0036 verifier: the characters list back button returns home', (
    tester,
  ) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;
    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    await shot(binding, tester, 'v01_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first character card');
    await letArtLoad(tester);
    expect(find.byType(BackButton), findsOneWidget, reason: 'list back button');
    await shot(binding, tester, 'v02_list_with_back_button');

    await tester.tap(find.text(first.name));
    await pumpUntil(tester, find.byKey(characterPreviewTitleKey), 'preview');
    expect(find.byType(BackButton), findsOneWidget, reason: 'no duplicate');
    await shot(binding, tester, 'v03_preview');

    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.byKey(charactersGridKey), 'the list again');
    await tester.pumpAndSettle();
    expect(find.byKey(characterPreviewTitleKey), findsNothing);
    expect(find.byType(BackButton), findsOneWidget, reason: 'still there');
    await shot(binding, tester, 'v04_list_after_preview');

    await tester.tap(find.byType(BackButton));
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'home again',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(charactersGridKey), findsNothing);
    await shot(binding, tester, 'v05_home_again');
  });
}
