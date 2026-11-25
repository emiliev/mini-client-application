import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:universe_sandbox/main.dart' as app;

import 'e2e_support.dart';

/// T-0033-AC3: the sandbox launches on the characters list, with real
/// fixture names and bundled art.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0033-AC3 the sandbox launches on the characters list with '
      'fixture names and art', (tester) async {
    final names = CharacterUniverse(42, defaultMockClock).byName;

    app.main();
    await pumpUntil(tester, find.text(names.first.name), 'the first card');

    expect(find.byKey(charactersGridKey), findsOneWidget);
    expect(find.text(names[1].name), findsOneWidget);
    expect(find.byType(Image), findsWidgets, reason: 'bundled art shows');
    await letArtLoad(tester);
    await shot(binding, tester, '01_sandbox_characters');
  });
}
