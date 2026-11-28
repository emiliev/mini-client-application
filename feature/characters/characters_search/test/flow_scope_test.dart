// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// initial query builds a new flow.
import 'package:characters_search/characters_search.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/characters_search_env.dart';

/// Counts for nothing: the root of the missing-type test has to forward
/// everything else the flow asks for.
class _NoTracker implements AnalyticsTracker {
  @override
  void trackEvent(String name, [Map<String, Object> params = const {}]) {}

  @override
  void trackScreen(String name) {}
}

void main() {
  setUpAll(bddSetUpAll);

  void serveSearch() =>
      McTestSession.current.backend.useFixtureSet('characters.default');

  mcTestWidgets(
    "T-0071-AC6 the flow's container resolves every registration",
    (tester) async {
      serveSearch();
      await openSearch(tester, initialQuery: 'spi');

      final page = tester.element(find.byKey(searchFieldKey));
      // Navigator, API, repository, the history (module), analytics port and
      // the bloc.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0071-AC1 a new initialQuery builds a new flow that searches it',
    (tester) async {
      serveSearch();
      final query = ValueNotifier<String>('spi');
      addTearDown(query.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: query,
          builder: (context, q, _) => searchTestHost(
            CharactersSearchFlow(navigator: searchNavigator(), initialQuery: q),
          ),
        ),
      );
      await letStorageFinish(tester);
      final first = tester.element(find.byKey(searchFieldKey));
      expect((flowStateOf<dynamic>(first) as dynamic).initialQuery, 'spi');
      expect(find.text('Spindle Alchemist'), findsOneWidget);

      query.value = 'amber';
      await letStorageFinish(tester);

      final second = tester.element(find.byKey(searchFieldKey));
      expect((flowStateOf<dynamic>(second) as dynamic).initialQuery, 'amber');
      expect(
        tester.widget<EditableText>(searchField()).controller.text,
        'amber',
      );
      expect(find.text('Amber Alchemist'), findsOneWidget);
      expect(find.text('Spindle Alchemist'), findsNothing);
      expect(
        [
          for (final r in McTestSession.current.backend.requests)
            r.query['nameStartsWith'],
        ],
        ['spi', 'amber'],
      );
    },
  );

  mcTestWidgets(
    'T-0071-AC1 a linked query with spaces is the same flow as the trimmed one',
    (tester) async {
      serveSearch();
      final query = ValueNotifier<String>(' spi');
      addTearDown(query.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: query,
          builder: (context, q, _) => searchTestHost(
            CharactersSearchFlow(navigator: searchNavigator(), initialQuery: q),
          ),
        ),
      );
      await letStorageFinish(tester);
      final first = tester.element(find.byKey(searchFieldKey));
      expect((flowStateOf<dynamic>(first) as dynamic).initialQuery, 'spi');
      expect(tester.widget<EditableText>(searchField()).controller.text, 'spi');

      query.value = 'spi';
      await letStorageFinish(tester);

      expect(
        tester.element(find.byKey(searchFieldKey)),
        same(first),
        reason: 'the same flow, not a new one',
      );
      expect(
        [
          for (final r in McTestSession.current.backend.requests)
            r.query['nameStartsWith'],
        ],
        ['spi'],
      );
    },
  );

  mcTestWidgets(
    'T-0071-AC2 the recent searches live under the key characters_search.history, '
    'newest first',
    (tester) async {
      serveSearch();
      await openSearch(tester);
      await tester.enterText(searchField(), 'amber');
      await mcSettle(tester);
      await tester.enterText(searchField(), 'spi');
      await mcSettle(tester);
      await letStorageFinish(tester);

      final store = tester.element(find.byKey(searchFieldKey)).di<FileStore>();
      final read = await tester.runAsync(
        () => store.read('characters_search.history'),
      );
      expect(read!.getOrNull(), ['spi', 'amber']);
      final global = await tester.runAsync(
        () => store.read('discovery_search.history'),
      );
      expect(global!.getOrNull(), isNull, reason: 'the global search is apart');
    },
  );

  mcTestWidgets(
    'T-0071-AC6 a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with everything but FileStore, which the flow forwards (the
      // recent searches).
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
            ..registerSingleton<AnalyticsTracker>(_NoTracker())
            ..registerSingleton<Dio>(session.backend.backend.createDio())
            ..registerSingleton<Monitoring>(session.monitoring);
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(
          session: session,
          home: searchTestHost(searchFlowUnderTest()),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<FileStore>'));
      expect(find.byKey(searchFieldKey), findsNothing);
    },
  );

  mcTestWidgets(
    'T-0071-AC6 the search page uses McAppBar with McFlowBackButton as '
    'leading',
    (tester) async {
      serveSearch();
      await openSearch(tester);

      final bar = tester.widget<McAppBar>(find.byType(McAppBar));
      expect(bar.leading, isA<McFlowBackButton>());
      expect(bar.title, 'Search');
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
