import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

/// R1: with the characters list (a flow) on screen, a link delivered to the
/// running app still opens its route. flow_builder 0.1.0 used to drop it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0033-AC4 a link sent to the running app opens its route '
      'while the characters list is shown', (tester) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the character list');
    expect(find.byKey(charactersGridKey), findsOneWidget);

    await pushLink(tester, 'miniclient://app/placeholder/42');
    await pumpUntil(
      tester,
      find.byKey(const Key('placeholder.detail')),
      'the linked placeholder',
    );

    expect(find.text('Placeholder detail 42'), findsOneWidget);
    await shot(binding, tester, '06_link_after_flow');
  });
}
