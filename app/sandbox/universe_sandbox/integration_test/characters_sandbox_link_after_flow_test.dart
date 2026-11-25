import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:universe_sandbox/main.dart' as app;

/// R1 in the sandbox, in its own scheme: with the list shown, a link sent to
/// the running app opens its route.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0033-AC3 a sandbox link sent to the running app opens its '
      'route while the characters list is shown', (tester) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;

    startApp(app.main);
    await pumpUntil(tester, find.text(first.name), 'the character list');
    expect(find.byKey(charactersGridKey), findsOneWidget);

    await pushLink(tester, 'miniclientuniverse://app/characters/${first.id}');
    await pumpUntil(
      tester,
      find.byKey(const Key('character.details.placeholder')),
      'the linked character details',
    );

    expect(find.text('Character details ${first.id}'), findsOneWidget);
    await shot(binding, tester, '03_sandbox_link_after_flow');
  });
}
