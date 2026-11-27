// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// characterId builds a new flow.
import 'package:characters_details/characters_details.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

import 'feature/util/characters_details_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  void serve() {
    McTestSession.current.backend
      ..useFixtureSet('characters.default')
      ..useFixtureSet('comics.default');
  }

  mcTestWidgets(
    "T-0067-AC1 the flow's container resolves every registration",
    (tester) async {
      serve();
      await initFlow(
        tester,
        () => charactersTestHost(characterDetailsFlowUnderTest(100002)),
      );
      await mcSettle(tester);

      final page = tester.element(find.byKey(characterDetailsBodyKey));
      // Navigator, API, repository, analytics port and both blocs.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0067-AC1 a new characterId builds a new flow that shows that character',
    (tester) async {
      serve();
      final character = ValueNotifier<int>(100002);
      addTearDown(character.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<int>(
          valueListenable: character,
          builder: (context, id, _) => charactersTestHost(
            CharacterDetailsFlow(
              navigator: charactersNavigator(),
              characterId: CharacterId(id),
            ),
          ),
        ),
      );
      await mcSettle(tester);
      expect(find.text(characterWithId(100002).name), findsWidgets);

      character.value = 100003;
      await mcSettle(tester);

      expect(find.text(characterWithId(100003).name), findsWidgets);
      expect(find.text(characterWithId(100002).name), findsNothing);
      expect(
        [
          for (final r in McTestSession.current.backend.requests)
            if (r.path.startsWith('/v1/characters/')) r.path,
        ],
        ['/v1/characters/100002', '/v1/characters/100003'],
      );
    },
  );

  for (final missing in ['SessionReader', 'AnalyticsTracker']) {
    mcTestWidgets('T-0067-AC1 a root without $missing fails naming it', (
      tester,
    ) async {
      final session = McTestSession.current;
      // A root with every forwarded type but [missing].
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
            ..registerSingleton<Dio>(session.backend.backend.createDio())
            ..registerSingleton<EventBus>(EventBus())
            ..registerSingleton<Monitoring>(session.monitoring);
          if (missing != 'AnalyticsTracker') {
            getIt.registerSingleton<AnalyticsTracker>(_NoTracker());
          }
          if (missing != 'SessionReader') {
            getIt.registerSingleton<SessionReader>(_NoSession());
          }
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(
          session: session,
          home: charactersTestHost(characterDetailsFlowUnderTest(100002)),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<$missing>'));
      expect(find.byKey(characterDetailsBodyKey), findsNothing);
    });
  }

  mcTestWidgets(
    'T-0067-AC1 the profile page uses McAppBar with McFlowBackButton as '
    'leading',
    (tester) async {
      serve();
      await initFlow(
        tester,
        () => charactersTestHost(characterDetailsFlowUnderTest(100002)),
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

  mcTestWidgets(
    'T-0067-AC1 the flow tracks its page as the screen character_details, '
    'once',
    (tester) async {
      serve();
      await initFlow(
        tester,
        () => charactersTestHost(characterDetailsFlowUnderTest(100002)),
      );
      await mcSettle(tester);

      expect(McTestSession.current.analytics.screens, ['character_details']);
    },
  );
}

final class _NoTracker implements AnalyticsTracker {
  @override
  void trackEvent(String name, [Map<String, Object> params = const {}]) {}

  @override
  void trackScreen(String name) {}
}

/// Never read: a flow fails at creation, before any bloc asks it anything.
class _NoSession extends Mock implements SessionReader {}
