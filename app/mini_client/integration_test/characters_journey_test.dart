import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

import 'e2e_support.dart';

/// T-0033-AC4 on a simulator, through the real `main()`: the production
/// boot, router, wiring, backend and bundled art. Run through
/// `tool/e2e_ios.sh` (see tool/e2e/README in the T-0033 task).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0033-AC4 home to the characters list, a preview, the full '
      'profile placeholder', (tester) async {
    // The first character of `characters.default` (seed 42), by the fixture
    // package's own facts.
    final first = CharacterUniverse(42, defaultMockClock).byName.first;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    expect(find.text('Characters'), findsOneWidget);
    await shot(binding, tester, '01_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first character card');
    expect(find.byKey(charactersGridKey), findsOneWidget);
    expect(find.byType(Image), findsWidgets, reason: 'bundled art shows');
    await letArtLoad(tester);
    await shot(binding, tester, '02_characters_list');

    await tester.tap(find.text(first.name));
    await pumpUntil(
      tester,
      find.text('See full profile'),
      'the preview with its profile button',
    );
    expect(find.byKey(characterPreviewTitleKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(characterPreviewTitleKey)).data,
      first.name,
    );
    await shot(binding, tester, '03_preview');

    await tester.tap(find.text('See full profile'));
    await pumpUntil(
      tester,
      find.byKey(const Key('character.details.placeholder')),
      'the character details placeholder',
    );
    expect(find.text('Character details ${first.id}'), findsOneWidget);
    await shot(binding, tester, '04_full_profile_placeholder');
  });
}
