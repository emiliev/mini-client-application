// Screen goldens of the flow (plan 05 §1.2), entered through the barrel: the
// settings in the 4 themes, compact against comfortable, signed in (synced
// and offline), the save failure, the explainer light and dark, and the
// pseudo-locale at 2x. Real Inter fonts on the 402x874 reference surface.
//
//   tool/bazelw run //feature/settings/settings_appearance:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/settings_appearance_env.dart';

Future<void> _open(
  WidgetTester tester, {
  String? signedInAs,
  VisualDensity? density,
}) async {
  McTestSession.current.backend.useFixtureSet('identity.default');
  await ensureSettingsContainer();
  if (signedInAs != null) {
    await signIn(tester, signedInAs);
  }
  await initFlow(
    tester,
    () => density == null
        ? settingsFlowUnderTest()
        : Builder(
            // The density `McApp` sets app-wide (ADR-0013).
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(visualDensity: density),
              child: settingsFlowUnderTest(),
            ),
          ),
  );
  await mcSettle(tester);
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  for (final variant in McThemeVariant.values) {
    mcTestWidgets('T-0063-AC4 golden: the settings in ${variant.name}', (
      tester,
    ) async {
      McTestSession.current.themeVariant = variant;
      await _open(tester);

      expect(find.text('Sync across devices'), findsOneWidget);
      await _expectGolden('settings_appearance_${variant.name}');
    });
  }

  mcTestWidgets('T-0063-AC4 golden: compact density, against the comfortable '
      'light golden', (tester) async {
    await _open(tester, density: VisualDensity.compact);
    // The control shows the choice the theme was set from.
    await appearance().change(density: AppearanceDensity.compact);
    await mcSettle(tester);

    await _expectGolden('settings_appearance_compact');
  });

  mcTestWidgets('T-0063-AC1 golden: signed in as the collector, synced, '
      'dark', (tester) async {
    McTestSession.current.themeVariant = McThemeVariant.dark;
    await _open(tester, signedInAs: 'collector@mini-client.test');

    expect(find.text('Synced with your account.'), findsOneWidget);
    await _expectGolden('settings_appearance_synced_dark');
  });

  mcTestWidgets('T-0063-AC2 golden: the account fails, offline with Retry', (
    tester,
  ) async {
    McTestSession.current.backend
      ..useFixtureSet('identity.default')
      ..backend.useScenario('identity.preferences_error');
    await ensureSettingsContainer();
    await signIn(tester, 'collector@mini-client.test');
    await initFlow(tester, settingsFlowUnderTest);
    await mcSettle(tester);

    expect(find.text('Retry'), findsOneWidget);
    await _expectGolden('settings_appearance_offline');
  });

  mcTestWidgets('T-0063-AC3 golden: the explainer, light and dark', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('About themes'));
    await mcSettle(tester);
    await _expectGolden('settings_appearance_about_light');
  });

  mcTestWidgets('T-0063-AC3 golden: the explainer in dark', (tester) async {
    McTestSession.current.themeVariant = McThemeVariant.dark;
    await _open(tester);
    await tester.tap(find.text('About themes'));
    await mcSettle(tester);
    await _expectGolden('settings_appearance_about_dark');
  });

  mcTestWidgets('T-0063-AC4 golden: the pseudo-locale at 2x', (tester) async {
    McTestSession.current
      ..locale = const Locale('en', 'XA')
      ..textScale = 2;
    await _open(tester);
    await _expectGolden('settings_appearance_pseudo_2x');
  });
}
