import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _results = ValueKey<String>('discovery_search.results');
const _filters = ValueKey<String>('discovery_search.filters');
const _history = ValueKey<String>('discovery_search.history');
const _comicTitle = ValueKey<String>('comics_details.title');

/// T-0046-AC5 on a simulator, through the real `main()`: home, Search, type
/// "spi", the grouped results, the Comics chip, a comic and its page; then
/// back to the results, and the cleared field shows the recent search. Run
/// through `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0046-AC5 home to the search, "spi", the results, a comic '
      'and its page; back, and the recent search', (tester) async {
    // Fixture facts (seed 42), from the discovery fixture's own ranking.
    final index = SearchIndex.fromUniverses(42, defaultMockClock);
    final character = index.search('spi', types: ['character']).first.entry;
    final comic = index.search('spi', types: ['comic']).first.entry;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    expect(find.text('Search'), findsOneWidget);
    await shot(binding, tester, '30_home_search_entry');

    await tester.tap(find.text('Search'));
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('discovery_search.field')),
      'the search page',
    );
    await shot(binding, tester, '31_search_opened');

    await tester.enterText(find.byType(EditableText), 'spi');
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(character.title),
      ),
      'the results for "spi"',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    expect(find.text('See all 152'), findsOneWidget);
    expect(find.text('See all 400'), findsOneWidget);
    await letArtLoad(tester);
    await shot(binding, tester, '32_search_results_grouped');

    await tester.tap(
      find.descendant(of: find.byKey(_filters), matching: find.text('Comics')),
    );
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(comic.title),
      ),
      'the comics of "spi"',
    );
    expect(
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(character.title),
      ),
      findsNothing,
    );
    await letArtLoad(tester, const Duration(seconds: 2));
    await shot(binding, tester, '33_search_comics_chip');

    await tester.tap(
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(comic.title),
      ),
    );
    await pumpUntil(tester, find.byKey(_comicTitle), 'the comic page');
    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, comic.title);
    await letArtLoad(tester);
    await shot(binding, tester, '34_comic_from_search');

    diContainer<RouterRef>().router.pop();
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(comic.title),
      ),
      'the results again',
    );
    expect(find.byKey(_comicTitle), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await pumpUntil(tester, find.byKey(_history), 'the recent searches');
    expect(
      find.descendant(of: find.byKey(_history), matching: find.text('spi')),
      findsOneWidget,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 600));
    await shot(binding, tester, '35_recent_searches');
  });
}
