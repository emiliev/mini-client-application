// T-0050 Verifier: en_XA screenshots of not-found and failed-load at 1x and
// 2x (rendered with --update-goldens, copied to the evidence). Not committed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/reading_list_editor_env.dart';

Future<void> _open(WidgetTester tester, String editing, double scale) async {
  McTestSession.current.backend
    ..useFixtureSet('comics.default')
    ..useFixtureSet('identity.default')
    ..useFixtureSet('library.default');
  await thePseudolocaleIsActive(tester);
  await theTextScaleIs(tester, scale);
  final bundle = McFixtureAssetBundle();
  await iAmSignedInAs(tester, 'reader@mini-client.test');
  await ensureEditorContainer();
  await initFlow(
    tester,
    () => editorTestHost(editorFlowUnderTest(editing: editing), bundle: bundle),
  );
  await mcSettle(tester);
}

void main() {
  setUpAll(bddSetUpAll);

  for (final scale in [1.0, 2.0]) {
    final s = scale.toInt();
    mcTestWidgets('V en_XA not found ${s}x', (tester) async {
      await _open(tester, 'l-4', scale);
      expect(find.text('[Ļíšţ ñóţ ƒóúñð ~~~~~~]'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/verifier_xa_not_found_${s}x.png'),
      );
    });

    mcTestWidgets('V en_XA load failed ${s}x', (tester) async {
      await theBackendFailsWith(
        tester,
        'GET /v1/me/lists/l-1',
        'server_error',
      );
      await _open(tester, 'l-1', scale);
      expect(
        find.text('[Ţĥé ŕéàðíñĝ ļíšţ çóúļð ñóţ ƀé ļóàðéð ~~~~~~~~~~~~~~]'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/verifier_xa_load_failed_${s}x.png'),
      );
    });
  }
}
