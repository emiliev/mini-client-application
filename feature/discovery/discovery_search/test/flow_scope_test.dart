// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// initial query builds a new flow.
import 'package:dio/dio.dart';
import 'package:discovery_search/discovery_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/discovery_search_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  void serveSearch() =>
      McTestSession.current.backend.useFixtureSet('discovery.default');

  mcTestWidgets(
    "T-0046-AC7 the flow's container resolves every registration",
    (tester) async {
      serveSearch();
      await openSearch(tester, initialQuery: 'spi');

      final page = tester.element(find.byKey(searchFieldKey));
      // Navigator, API, repository, the history (module) and the bloc.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0046-AC5 a new initialQuery builds a new flow that searches it',
    (tester) async {
      serveSearch();
      final query = ValueNotifier<String>('spi');
      addTearDown(query.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: query,
          builder: (context, q, _) => searchTestHost(
            DiscoverySearchFlow(navigator: searchNavigator(), initialQuery: q),
          ),
        ),
      );
      await letStorageFinish(tester);
      final first = tester.element(find.byKey(searchFieldKey));
      expect(
        (flowStateOf<dynamic>(first) as dynamic).initialQuery,
        'spi',
      );
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
        [for (final r in McTestSession.current.backend.requests) r.query['q']],
        ['spi', 'amber'],
      );
    },
  );

  mcTestWidgets(
    'T-0046-AC7 a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with Dio and Monitoring, but no FileStore, which the flow
      // forwards (the recent searches).
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
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
    'T-0046-AC7 the search page uses McAppBar with McFlowBackButton as '
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
