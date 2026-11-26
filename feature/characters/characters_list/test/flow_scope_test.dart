// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// team builds a new flow.
import 'package:characters_list/characters_list.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/characters_list_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets(
    "T-0032-AC6 the flow's container resolves every registration",
    (tester) async {
      McTestSession.current.backend.useFixtureSet('characters.default');
      await initFlow(
        tester,
        () => charactersTestHost(charactersListFlowUnderTest()),
      );
      await mcSettle(tester);

      final page = tester.element(find.byKey(charactersGridKey));
      // Navigator, API, repository and the list bloc; the preview bloc takes
      // a factory parameter and is skipped by design (F-0018 fact 5).
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0032-AC1 a new initialTeamId builds a new flow that lists that team',
    (tester) async {
      final backend = McTestSession.current.backend
        ..useFixtureSet('characters.default');
      final team = ValueNotifier<String>('red');
      addTearDown(team.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: team,
          builder: (context, id, _) => charactersTestHost(
            CharactersListFlow(
              navigator: charactersNavigator(),
              initialTeamId: id,
            ),
          ),
        ),
      );
      await mcSettle(tester);
      expect(charactersFlowState(tester).teamId, 'red');

      team.value = 'blue';
      await mcSettle(tester);

      expect(charactersFlowState(tester).teamId, 'blue');
      expect(
        [for (final r in backend.requests) r.query['team']],
        [
          'red',
          'blue',
        ],
      );
    },
  );

  mcTestWidgets(
    'T-0032-AC6 a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with Dio but no Monitoring, which the flow forwards.
      await initializeDIContainer([
        McDIInitializer(
          (getIt, _) => getIt.registerSingleton<Dio>(
            session.backend.backend.createDio(),
          ),
        ),
      ]);
      await tester.pumpWidget(
        McTestApp(
          session: session,
          home: charactersTestHost(charactersListFlowUnderTest()),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<Monitoring>'));
      expect(find.byKey(charactersGridKey), findsNothing);
    },
  );

  mcTestWidgets(
    'T-0040-AC3 the list page uses McAppBar with McFlowBackButton as leading',
    (tester) async {
      McTestSession.current.backend.useFixtureSet('characters.default');
      await initFlow(
        tester,
        () => charactersTestHost(charactersListFlowUnderTest()),
      );
      await mcSettle(tester);

      final bar = tester.widget<McAppBar>(find.byType(McAppBar));
      expect(bar.leading, isA<McFlowBackButton>());
      // The DS bar draws the flow's widget inside its own AppBar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(McFlowBackButton),
        ),
        findsOneWidget,
      );
      expect(find.text('Characters'), findsOneWidget);
    },
  );
}
