// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// comic builds a new flow.
import 'package:comics_details/comics_details.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/comics_details_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  void serveComics() =>
      McTestSession.current.backend..useFixtureSet('comics.default');

  mcTestWidgets(
    "T-0041-AC7 the flow's container resolves every registration",
    (tester) async {
      serveComics();
      await initFlow(
        tester,
        () => comicsTestHost(comicsDetailsFlowUnderTest(501500)),
      );
      await mcSettle(tester);

      final page = tester.element(find.byKey(comicDetailsBodyKey));
      // Navigator, API, repository and both blocs (no factory parameters).
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0041-AC1 a new comicId builds a new flow that shows that comic',
    (tester) async {
      serveComics();
      final comic = ValueNotifier<int>(501500);
      addTearDown(comic.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<int>(
          valueListenable: comic,
          builder: (context, id, _) => comicsTestHost(
            ComicsDetailsFlow(
              navigator: comicsNavigator(),
              comicId: ComicId(id),
            ),
          ),
        ),
      );
      await mcSettle(tester);
      expect(find.text(comicRecord(501500).title), findsWidgets);

      comic.value = 500000;
      await mcSettle(tester);

      final body = find.byKey(comicDetailsBodyKey);
      expect(comicsFlowState(tester, body).comicId, const ComicId(500000));
      expect(find.text(comicRecord(500000).title), findsWidgets);
      expect(find.text(comicRecord(501500).title), findsNothing);
      expect(
        [
          for (final r in McTestSession.current.backend.requests)
            if (r.path.startsWith('/v1/comics/')) r.path,
        ],
        ['/v1/comics/501500', '/v1/comics/500000'],
      );
    },
  );

  mcTestWidgets(
    'T-0041-AC7 a root without a forwarded type fails naming it',
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
          home: comicsTestHost(comicsDetailsFlowUnderTest(501500)),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<SessionReader>'));
      expect(find.byKey(comicDetailsBodyKey), findsNothing);
    },
  );

  mcTestWidgets(
    'T-0041-AC7 the details page uses McAppBar with McFlowBackButton as '
    'leading',
    (tester) async {
      serveComics();
      await initFlow(
        tester,
        () => comicsTestHost(comicsDetailsFlowUnderTest(501500)),
      );
      await mcSettle(tester);

      final bar = tester.widget<McAppBar>(find.byType(McAppBar));
      expect(bar.leading, isA<McFlowBackButton>());
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(McFlowBackButton),
        ),
        findsOneWidget,
      );
    },
  );
}
