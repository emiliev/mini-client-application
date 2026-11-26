// Screen goldens of the flow (plan 05 §1.2), entered through the barrel:
// the list loaded, failed and empty, and the preview. Real Inter fonts and
// the bundled fixture art, on the 402x874 reference surface.
//
//   tool/bazelw run //feature/characters/characters_list:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/characters_list_env.dart';

final List<String> _art = [
  for (var i = 0; i < placeholderSets['characters']!; i++)
    'packages/mc_fixtures_media/assets/characters/'
        '${i.toString().padLeft(3, '0')}.png',
];

/// Opens the list on [set] with every placeholder picture decoded first, so
/// the first frame draws the art (F-0030).
Future<void> _open(WidgetTester tester, String set) async {
  McTestSession.current.backend
    ..useFixtureSet(set)
    // The preview lists the character's comics (T-0041).
    ..useFixtureSet('comics.default');
  final bundle = McFixtureAssetBundle();
  await mcPrecacheFixtureImages(tester, bundle, _art);
  await initFlow(
    tester,
    () => charactersTestHost(charactersListFlowUnderTest(), bundle: bundle),
  );
  await mcSettle(tester);
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets('T-0032-AC1 golden: the first page loaded', (tester) async {
    await _open(tester, 'characters.default');

    expect(find.text('Amber Alchemist'), findsOneWidget);
    await _expectGolden('characters_list_loaded');
  });

  mcTestWidgets('T-0032-AC2 golden: the first page failed', (tester) async {
    McTestSession.current.backend.fail(
      'GET /v1/characters',
      BackendFailure.serverError,
    );
    await _open(tester, 'characters.default');

    expect(find.text('Characters could not be loaded'), findsOneWidget);
    await _expectGolden('characters_list_error');
  });

  mcTestWidgets('golden: the empty catalogue', (tester) async {
    await _open(tester, 'characters.empty');

    expect(find.text('No characters yet'), findsOneWidget);
    await _expectGolden('characters_list_empty');
  });

  mcTestWidgets('T-0032-AC3 golden: the preview', (tester) async {
    await _open(tester, 'characters.default');
    await tester.tap(find.text('Amber Alchemist'));
    await mcSettle(tester);

    expect(find.byKey(characterPreviewTitleKey), findsOneWidget);
    await _expectGolden('character_preview');
  });
}
