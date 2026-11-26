// Screen goldens of the flow (plan 05 §1.2), entered through the barrel: the
// comic loaded (top and bottom), failed and not found, and the cover page.
// Real Inter fonts and the bundled fixture art, on the 402x874 reference
// surface.
//
//   tool/bazelw run //feature/comics/comics_details:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/comics_details_env.dart';

final List<String> _art = [
  for (var i = 0; i < placeholderSets['characters']!; i++)
    'packages/mc_fixtures_media/assets/characters/'
        '${i.toString().padLeft(3, '0')}.png',
];

/// Opens comic [id] with every placeholder picture decoded first, so the
/// first frame draws the art (F-0030).
Future<void> _open(WidgetTester tester, int id) async {
  McTestSession.current.backend..useFixtureSet('comics.default');
  final bundle = McFixtureAssetBundle();
  await mcPrecacheFixtureImages(tester, bundle, _art);
  await ensureComicsContainer();
  await initFlow(
    tester,
    () => comicsTestHost(comicsDetailsFlowUnderTest(id), bundle: bundle),
  );
  await mcSettle(tester);
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets('T-0041-AC1 golden: the comic loaded, top', (tester) async {
    await _open(tester, 501500);

    expect(find.byKey(comicTitleKey), findsOneWidget);
    await _expectGolden('comic_details_top');
  });

  mcTestWidgets('T-0041-AC1 golden: the comic loaded, bottom', (
    tester,
  ) async {
    await _open(tester, 501500);
    await scrollComicUntilVisible(tester, find.byKey(comicCastKey));
    await tester.drag(comicBodyScrollable().first, const Offset(0, -2000));
    await mcSettle(tester);

    expect(find.byKey(comicCastKey), findsOneWidget);
    await _expectGolden('comic_details_bottom');
  });

  mcTestWidgets('T-0041-AC2 golden: the comic failed', (tester) async {
    McTestSession.current.backend.fail(
      'GET /v1/comics/501500',
      BackendFailure.serverError,
    );
    await _open(tester, 501500);

    expect(find.text('The comic could not be loaded'), findsOneWidget);
    await _expectGolden('comic_details_error');
  });

  mcTestWidgets('T-0041-AC2 golden: the comic was not found', (tester) async {
    await _open(tester, 999999);

    expect(find.text('Comic not found'), findsOneWidget);
    await _expectGolden('comic_details_not_found');
  });

  mcTestWidgets('golden: the cover page', (tester) async {
    await _open(tester, 501500);
    await tester.tap(find.byKey(comicCoverKey));
    await mcSettle(tester);

    expect(find.byKey(comicCoverPageImageKey), findsOneWidget);
    await _expectGolden('comic_cover');
  });
}
