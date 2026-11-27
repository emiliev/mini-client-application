// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The bloc is the flow's own: one per flow,
// closed with the flow.
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/auth_signin_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets(
    "T-0066-AC1 the flow's container resolves every registration",
    (tester) async {
      McTestSession.current.backend.useFixtureSet('identity.default');
      await McTestContainer.initialize(McTestSession.current);
      await initFlow(tester, () => signInFlowUnderTest());
      await mcSettle(tester);

      final page = tester.element(find.byKey(signInFormKey));
      // Navigator, repository, bloc (no factory parameters).
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    'T-0066-AC1 a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with Monitoring but no `AuthApi`, which the flow forwards.
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt.registerSingleton<Monitoring>(session.monitoring);
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(session: session, home: signInFlowUnderTest()),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<AuthApi>'));
      expect(find.byKey(signInFormKey), findsNothing);
    },
  );

  mcTestWidgets(
    'T-0066-AC1 the page uses McAppBar with McFlowBackButton as leading',
    (tester) async {
      McTestSession.current.backend.useFixtureSet('identity.default');
      await McTestContainer.initialize(McTestSession.current);
      await initFlow(tester, () => signInFlowUnderTest());
      await mcSettle(tester);

      final bar = tester.widget<McAppBar>(find.byType(McAppBar));
      expect(bar.leading, isA<McFlowBackButton>());
    },
  );
}
