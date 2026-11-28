// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The page uses the DS app bar and the flow back
// button, and follows the app's theme variants and density.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

import 'feature/util/settings_home_env.dart';

class _Session extends Mock implements SessionReader {}

class _Appearance extends Mock implements AppearanceReader {}

final class _NoTracker implements AnalyticsTracker {
  @override
  void trackEvent(String name, [Map<String, Object>? params]) {}

  @override
  void trackScreen(String name) {}
}

void main() {
  setUpAll(bddSetUpAll);

  Future<void> open(WidgetTester tester) async {
    await ensureSettingsContainer();
    await initFlow(tester, settingsFlowUnderTest);
    await mcSettle(tester);
  }

  mcTestWidgets(
    "T-0070-AC5 the flow's container resolves every registration",
    (tester) async {
      await open(tester);
      final page = tester.element(find.byKey(settingsBodyKey));
      // The navigator, the flow controller, the profile reader and the bloc.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  for (final missing in [
    'AnalyticsTracker',
    'AppConfig',
    'AppearanceReader',
    'Dio',
    'SessionReader',
  ]) {
    mcTestWidgets('T-0070-AC5 a root without $missing fails naming it', (
      tester,
    ) async {
      final session = McTestSession.current;
      // A root with every forwarded type but [missing].
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt.registerSingleton<Monitoring>(session.monitoring);
          if (missing != 'AnalyticsTracker') {
            getIt.registerSingleton<AnalyticsTracker>(_NoTracker());
          }
          if (missing != 'AppConfig') {
            getIt.registerSingleton<AppConfig>(McTestContainer.config);
          }
          if (missing != 'AppearanceReader') {
            getIt.registerSingleton<AppearanceReader>(_Appearance());
          }
          if (missing != 'Dio') {
            getIt.registerSingleton<Dio>(Dio());
          }
          if (missing != 'SessionReader') {
            getIt.registerSingleton<SessionReader>(_Session());
          }
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(session: session, home: settingsFlowUnderTest()),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<$missing>'));
      expect(find.byKey(settingsBodyKey), findsNothing);
    });
  }

  mcTestWidgets('T-0070-AC5 the page uses McAppBar with McFlowBackButton as '
      'leading', (tester) async {
    await open(tester);
    final bar = tester.widget<McAppBar>(find.byType(McAppBar));
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'Settings');
  });

  for (final variant in McThemeVariant.values) {
    mcTestWidgets('T-0070-AC4 the index builds in ${variant.name}, in its '
        'palette, and nothing overflows', (tester) async {
      McTestSession.current.themeVariant = variant;
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byKey(settingsBodyKey))).brightness,
        McPalette.of(variant).brightness,
      );
      expect(find.text('Not signed in'), findsOneWidget);
    });
  }

  for (final scale in [1.0, 2.0]) {
    mcTestWidgets('T-0070-AC4 at ${scale}x text, Compact tightens the gap '
        'between sections, and nothing overflows', (tester) async {
      McTestSession.current.textScale = scale;
      await ensureSettingsContainer();
      final compact = ValueNotifier<bool>(false);
      addTearDown(compact.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<bool>(
          valueListenable: compact,
          builder: (context, on, child) => Theme(
            data: Theme.of(context).copyWith(
              visualDensity: on
                  ? VisualDensity.compact
                  : VisualDensity.standard,
            ),
            child: child!,
          ),
          child: settingsFlowUnderTest(),
        ),
      );
      await mcSettle(tester);
      // From the account button to the Appearance row.
      double gap() =>
          tester.getTopLeft(find.byKey(rowKey('appearance'))).dy -
          tester.getBottomLeft(find.byKey(rowKey('sign_in'))).dy;
      final comfortable = gap();

      compact.value = true;
      await mcSettle(tester);
      expect(gap(), lessThan(comfortable));
      expect(tester.takeException(), isNull);
    });
  }
}
