import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

/// T-0053-AC4 on a simulator, through the real `main()`: the production boot,
/// router and root list, with the bundled `e2e` config (consent granted by
/// default). A recorder sink is attached to the running `Analytics` once home
/// shows (the gate is still in front of it), and home -> characters -> back
/// must report `characters_list`, then `home`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0053-AC4 home to the characters list and back records the '
      'screens', (tester) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    final analytics = diContainer<Analytics>();
    expect(
      analytics.consent,
      AnalyticsConsent.granted,
      reason: 'the e2e config grants consent by default',
    );
    final sink = InMemoryAnalyticsSink();
    analytics.addSink(sink);
    await tester.pump(const Duration(milliseconds: 100));
    expect(sink.screens, isEmpty, reason: 'nothing before the first move');
    await shot(binding, tester, '01_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first character card');
    expect(find.byKey(charactersGridKey), findsOneWidget);
    expect(sink.screens, ['characters_list']);
    await letArtLoad(tester);
    await shot(binding, tester, '02_characters_list');

    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'home again',
    );
    expect(sink.screens, ['characters_list', 'home']);
    // One session, numbered from the first entry the recorder saw, no gaps.
    final seqs = sink.records.map((r) => r.seq).toList();
    expect(seqs, [
      for (var i = seqs.first; i < seqs.first + seqs.length; i++) i,
    ]);
    expect(sink.records.map((r) => r.sessionId).toSet(), {
      analytics.sessionId,
    });
    await shot(binding, tester, '03_back_to_home');
  });
}
