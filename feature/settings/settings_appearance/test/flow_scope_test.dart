// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). Both pages use the DS app bar and the flow
// back button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/settings_appearance_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  Future<void> open(WidgetTester tester) async {
    await ensureSettingsContainer();
    await initFlow(tester, settingsFlowUnderTest);
    await mcSettle(tester);
  }

  mcTestWidgets(
    "T-0063-AC7 the flow's container resolves every registration",
    (tester) async {
      await open(tester);
      final page = tester.element(find.byKey(appearanceBodyKey));
      // The navigator, the flow controller and the bloc.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  for (final missing in ['AppearanceSettings', 'AnalyticsTracker']) {
    mcTestWidgets('T-0063-AC7 a root without $missing fails naming it', (
      tester,
    ) async {
      final session = McTestSession.current;
      final dummy = _DeviceOnly();
      // A root with every forwarded type but [missing].
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt.registerSingleton<Monitoring>(session.monitoring);
          if (missing != 'AppearanceSettings') {
            getIt.registerSingleton<AppearanceSettings>(dummy);
          }
          if (missing != 'AnalyticsTracker') {
            getIt.registerSingleton<AnalyticsTracker>(_NoTracker());
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
      expect(find.byKey(appearanceBodyKey), findsNothing);
    });
  }

  mcTestWidgets('T-0063-AC7 both pages use McAppBar with McFlowBackButton as '
      'leading', (tester) async {
    await open(tester);
    var bar = tester.widget<McAppBar>(find.byType(McAppBar));
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'Appearance');

    await tester.tap(find.text('About themes'));
    await mcSettle(tester);
    bar = tester.widget<McAppBar>(find.byType(McAppBar).last);
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'About themes');
    expect(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.byType(BackButton),
      ),
      findsOneWidget,
      reason: 'the explainer goes back inside the flow',
    );
  });

  mcTestWidgets('T-0063-AC4 the screen tightens under a compact density', (
    tester,
  ) async {
    await ensureSettingsContainer();
    final compact = ValueNotifier<bool>(false);
    addTearDown(compact.dispose);
    await initFlow(
      tester,
      () => ValueListenableBuilder<bool>(
        valueListenable: compact,
        builder: (context, on, child) => Theme(
          data: Theme.of(context).copyWith(
            visualDensity: on ? VisualDensity.compact : VisualDensity.standard,
          ),
          child: child!,
        ),
        child: settingsFlowUnderTest(),
      ),
    );
    await mcSettle(tester);
    // Between two groups (the theme control and the density header), and
    // between a header and its control: each tightens on its own.
    double groupGap() =>
        tester.getTopLeft(find.text('Density')).dy -
        tester.getBottomLeft(find.byKey(themeModeKey('system'))).dy;
    double headerGap() =>
        tester.getTopLeft(find.byKey(densityKey('comfortable'))).dy -
        tester.getBottomLeft(find.text('Density')).dy;
    final group = groupGap();
    final header = headerGap();
    final switchHeight = tester.getSize(find.byKey(reduceMotionKey)).height;

    compact.value = true;
    await mcSettle(tester);
    expect(groupGap(), lessThan(group));
    expect(headerGap(), lessThan(header));
    expect(
      tester.getSize(find.byKey(reduceMotionKey)).height,
      lessThan(switchHeight),
      reason: 'the Material row follows the density too',
    );
  });
}

/// A stand-in that keeps the defaults: the failing root only needs a type.
final class _DeviceOnly implements AppearanceSettings {
  @override
  Stream<AppearanceSnapshot> get changes => const Stream.empty();

  @override
  AppearanceSnapshot get snapshot => const AppearanceSnapshot(
    preferences: AppearancePreferences.defaults,
    status: AppearanceSyncStatus.local,
  );

  @override
  Future<void> change({
    AppearanceThemeMode? themeMode,
    AppearanceDensity? density,
    bool? reduceMotion,
  }) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> retry() async {}
}

final class _NoTracker implements AnalyticsTracker {
  @override
  void trackEvent(String name, [Map<String, Object>? params]) {}

  @override
  void trackScreen(String name) {}
}
