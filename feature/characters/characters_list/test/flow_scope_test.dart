// R17: the flow's hand-written root imports (lib/src/di/flow_scope.dart) are
// complete, and a missing one fails at flow creation, naming the type. Only
// the barrel is imported; `mcgen wire` will generate the list (Phase D).
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
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
}
