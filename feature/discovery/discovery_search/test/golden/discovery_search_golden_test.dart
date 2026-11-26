// Screen goldens of the flow (plan 05 §1.2), entered through the barrel: the
// recent searches, the results under "All" and under one type, nothing
// found, and a failed search. Real Inter fonts and the bundled fixture art,
// on the 402x874 reference surface.
//
//   tool/bazelw run //feature/discovery/discovery_search:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/discovery_search_env.dart';

final List<String> _art = [
  for (var i = 0; i < placeholderSets['characters']!; i++)
    'packages/mc_fixtures_media/assets/characters/'
        '${i.toString().padLeft(3, '0')}.png',
];

/// Opens the search with every placeholder picture decoded first, so the
/// first frame draws the art (F-0030). The field is unfocused (no cursor),
/// so the picture does not depend on the caret's blink.
Future<void> _open(WidgetTester tester) async {
  McTestSession.current.backend.useFixtureSet('discovery.default');
  final bundle = McFixtureAssetBundle();
  await mcPrecacheFixtureImages(tester, bundle, _art);
  await initFlow(
    tester,
    () => searchTestHost(searchFlowUnderTest(), bundle: bundle),
  );
  await letStorageFinish(tester);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(searchField(), text);
  await mcSettle(tester);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets('T-0046-AC6 golden: the recent searches', (tester) async {
    await _open(tester);
    for (final query in ['amber', 'spire', 'spi']) {
      await _type(tester, query);
    }
    await letStorageFinish(tester);
    await _type(tester, '');

    expect(shownHistory(tester), ['spi', 'spire', 'amber']);
    await _expectGolden('search_recent');
  });

  mcTestWidgets('T-0046-AC1 golden: the results under All', (tester) async {
    await _open(tester);
    await _type(tester, 'spi');

    expect(find.byKey(searchResultsKey), findsOneWidget);
    await _expectGolden('search_results_all');
  });

  mcTestWidgets('T-0046-AC1 golden: the results under Comics', (tester) async {
    await _open(tester);
    await _type(tester, 'spi');
    await tester.tap(
      find.descendant(
        of: find.byKey(searchFiltersKey),
        matching: find.text('Comics'),
      ),
    );
    await mcSettle(tester);

    expect(chipSelected(tester, 'Comics'), isTrue);
    await _expectGolden('search_results_comics');
  });

  mcTestWidgets('T-0046-AC2 golden: nothing found', (tester) async {
    await _open(tester);
    await _type(tester, 'zzzz');

    expect(find.text('No results'), findsOneWidget);
    await _expectGolden('search_empty');
  });

  mcTestWidgets('T-0046-AC2 golden: the search failed', (tester) async {
    McTestSession.current.backend.fail(
      'GET /v1/search',
      BackendFailure.serverError,
    );
    await _open(tester);
    await _type(tester, 'spi');

    expect(find.text('The search failed'), findsOneWidget);
    await _expectGolden('search_error');
  });
}
