// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The editor bloc is the flow's own: one per
// flow, shared by the step pages, closed with the flow.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/reading_list_editor_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  Future<void> signIn(WidgetTester tester) async {
    final session = McTestSession.current
      ..backend.useFixtureSet('comics.default')
      ..backend.useFixtureSet('identity.default')
      ..backend.useFixtureSet('library.default');
    await McTestContainer.initialize(session);
    await iAmSignedInAs(tester, 'reader@mini-client.test');
  }

  mcTestWidgets(
    "T-0048-AC7 the flow's container resolves every registration",
    (tester) async {
      await signIn(tester);
      await initFlow(tester, () => editorTestHost(editorFlowUnderTest()));
      await mcSettle(tester);

      final page = tester.element(find.byKey(detailsBodyKey));
      // Navigator, API, repository, both blocs (no factory parameters).
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0048-AC7 a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with Dio, the bus and Monitoring, but no session, which the
      // flow forwards.
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
            ..registerSingleton<Dio>(session.backend.backend.createDio())
            ..registerSingleton<EventBus>(EventBus())
            ..registerSingleton<Monitoring>(session.monitoring);
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(
          session: session,
          home: editorTestHost(editorFlowUnderTest()),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<SessionReader>'));
      expect(find.byKey(detailsBodyKey), findsNothing);
    },
  );

  mcTestWidgets(
    'T-0048-AC7 every step page uses McAppBar with McFlowBackButton as '
    'leading',
    (tester) async {
      await signIn(tester);
      await initFlow(
        tester,
        () => editorTestHost(editorFlowUnderTest(editing: 'l-1')),
      );
      await mcSettle(tester);
      for (var step = 0; step < 3; step++) {
        final bar = tester.widget<McAppBar>(find.byType(McAppBar));
        expect(bar.leading, isA<McFlowBackButton>(), reason: 'step $step');
        if (step < 2) {
          await tester.tap(find.text('Next'));
          await mcSettle(tester);
        }
      }
      expect(editorFlowState(tester, editorAnchor()).step, 2);
    },
  );

  mcTestWidgets(
    'T-0048-AC6 an editor closed while its save is held hands out nothing '
    'when the save returns',
    (tester) async {
      await signIn(tester);
      final open = ValueNotifier<bool>(true);
      addTearDown(open.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<bool>(
          valueListenable: open,
          builder: (context, isOpen, _) => isOpen
              ? editorTestHost(editorFlowUnderTest(editing: 'l-1'))
              : const SizedBox.shrink(),
        ),
      );
      await mcSettle(tester);
      await ensureEditorContainer();
      await enterText(tester, 'Name', 'Spider-Verse Basics');
      await tester.tap(find.text('Next'));
      await mcSettle(tester);
      await tester.tap(find.text('Next'));
      await mcSettle(tester);
      await tapTooltip(tester, 'Move Amber Legacy #1 up');
      final backend = McTestSession.current.backend
        ..hold('PUT /v1/me/lists/l-1');
      await tester.tap(find.text('Save changes'));
      await theAppSends(tester, 'PUT /v1/me/lists/l-1');

      // The host removes the editor (a route change) while the write waits.
      open.value = false;
      await tester.pump();
      await backend.release('PUT /v1/me/lists/l-1');
      await mcSettle(tester);

      expect(tester.takeException(), isNull);
      expect(editorResults(), isEmpty, reason: 'no result after closing');
      expect(announcedChanges(), isEmpty);
      // The flow was gone before the details returned: the items were never
      // sent.
      expect(
        backend.requests.where(
          (r) => matchesRequest(r, 'PUT /v1/me/lists/l-1/items'),
        ),
        isEmpty,
      );
    },
  );

  mcTestWidgets(
    'T-0048-AC3 a different list builds a new flow that loads that list',
    (tester) async {
      await signIn(tester);
      final list = ValueNotifier<String>('l-1');
      addTearDown(list.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: list,
          builder: (context, id, _) =>
              editorTestHost(editorFlowUnderTest(editing: id)),
        ),
      );
      await mcSettle(tester);
      expectFieldText(tester, 'Name', 'Spider-Verse Starter');

      list.value = 'l-2';
      await mcSettle(tester);

      expect(
        editorFlowState(tester, editorAnchor()).editing,
        const ReadingListId('l-2'),
      );
      expectFieldText(tester, 'Name', 'Weekend Reads');
      expect(
        [
          for (final r in McTestSession.current.backend.requests)
            if (r.path.startsWith('/v1/me/lists/')) r.path,
        ],
        ['/v1/me/lists/l-1', '/v1/me/lists/l-2'],
      );
    },
  );
}
