// Screen goldens of the flow (plan 05 §1.2), entered through the barrel:
// every step, a blocked step with its error, a failed save, and the states
// outside the wizard. Real Inter fonts and the bundled fixture art, on the
// 402x874 reference surface.
//
//   tool/bazelw run //feature/library/library_reading_list_editor:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/reading_list_editor_env.dart';

final List<String> _art = [
  for (var i = 0; i < placeholderSets['characters']!; i++)
    'packages/mc_fixtures_media/assets/characters/'
        '${i.toString().padLeft(3, '0')}.png',
];

/// Signs the reader in and opens the editor (for [editing], or a new list)
/// with every placeholder picture decoded first, so the first frame draws
/// the art (F-0030).
Future<void> _open(WidgetTester tester, {String? editing}) async {
  McTestSession.current.backend
    ..useFixtureSet('comics.default')
    ..useFixtureSet('identity.default')
    ..useFixtureSet('library.default');
  final bundle = McFixtureAssetBundle();
  await mcPrecacheFixtureImages(tester, bundle, _art);
  await iAmSignedInAs(tester, 'reader@mini-client.test');
  await ensureEditorContainer();
  await initFlow(
    tester,
    () => editorTestHost(editorFlowUnderTest(editing: editing), bundle: bundle),
  );
  await mcSettle(tester);
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await mcSettle(tester);
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets('T-0048-AC1 golden: step 1, details filled in', (tester) async {
    await _open(tester);
    await enterText(tester, 'Name', 'Amber reads');
    await enterText(tester, 'Description (optional)', 'Where Amber begins.');
    await tester.tap(find.text('Public'));
    await mcSettle(tester);

    await _expectGolden('step1_details');
  });

  mcTestWidgets('T-0048-AC6 golden: step 1, a blocked Next shows the error', (
    tester,
  ) async {
    await _open(tester);
    await _next(tester);

    expect(find.text('Give your list a name.'), findsOneWidget);
    await _expectGolden('step1_blocked');
  });

  mcTestWidgets('T-0048-AC1 golden: step 2, comics picked', (tester) async {
    await _open(tester);
    await enterText(tester, 'Name', 'Amber reads');
    await _next(tester);
    await pickComic(tester, 'Amber Chronicles #1');
    await pickComic(tester, 'Amber Chronicles #3');

    expect(find.text('2 comics picked'), findsOneWidget);
    await _expectGolden('step2_comics');
  });

  mcTestWidgets('T-0048-AC3 golden: step 3, the reading order of a list', (
    tester,
  ) async {
    await _open(tester, editing: 'l-1');
    await _next(tester);
    await _next(tester);

    expect(find.text('Save changes'), findsOneWidget);
    await _expectGolden('step3_review');
  });

  mcTestWidgets('T-0048-AC2 golden: step 3, a failed save', (tester) async {
    McTestSession.current.backend.fail(
      'PUT /v1/me/lists/l-1',
      BackendFailure.serverError,
    );
    await _open(tester, editing: 'l-1');
    await enterText(tester, 'Name', 'Spider-Verse Basics');
    await _next(tester);
    await _next(tester);
    await tester.tap(find.text('Save changes'));
    await mcSettle(tester);

    expect(find.text('The list could not be saved'), findsOneWidget);
    await _expectGolden('step3_save_failed');
  });

  mcTestWidgets('T-0048-AC3 golden: a list that is not the reader\'s', (
    tester,
  ) async {
    await _open(tester, editing: 'l-4');

    expect(find.text('List not found'), findsOneWidget);
    await _expectGolden('not_found');
  });

  mcTestWidgets('T-0048-AC6 golden: the session ended', (tester) async {
    await _open(tester);
    await endSessionElsewhere(tester);

    expect(find.text('You are no longer signed in as before'), findsOneWidget);
    await _expectGolden('session_ended');
  });
}
