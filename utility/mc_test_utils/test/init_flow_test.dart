import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'support.dart';

void main() {
  setUpAll(registerThingsSet);

  mcTestWidgets('T-0026-AC4 initFlow gives the DS theme, en and iOS', (
    tester,
  ) async {
    McTestSession.current.backend.useFixtureSet(thingsSet);
    late ThemeData theme;
    late Locale locale;
    late TargetPlatform platform;
    late double scale;
    await initFlow(
      tester,
      () => thingsFlow(
        onBuild: (context) {
          theme = Theme.of(context);
          locale = Localizations.localeOf(context);
          platform = defaultTargetPlatform;
          scale = MediaQuery.textScalerOf(context).scale(10);
        },
      ),
    );
    await mcSettle(tester);

    expect(theme.extension<McThemeExtension>()?.variant, McThemeVariant.light);
    expect(theme.platform, TargetPlatform.iOS);
    expect(theme.colorScheme.primary, McTheme.light.colorScheme.primary);
    expect(locale, const Locale('en'));
    expect(platform, TargetPlatform.iOS);
    expect(scale, 10);
    expect(find.text('alpha,beta'), findsOneWidget);
  });

  mcTestWidgets('initFlow honours the session text scale and variant', (
    tester,
  ) async {
    McTestSession.current
      ..backend.useFixtureSet(thingsSet)
      ..textScale = 2
      ..themeVariant = McThemeVariant.dark;
    late ThemeData theme;
    late double scale;
    await initFlow(
      tester,
      () => thingsFlow(
        onBuild: (context) {
          theme = Theme.of(context);
          scale = MediaQuery.textScalerOf(context).scale(10);
        },
      ),
    );
    await mcSettle(tester);
    expect(theme.extension<McThemeExtension>()?.variant, McThemeVariant.dark);
    expect(scale, 20);
  });

  mcTestWidgets('the flow reaches the root monitoring double', (tester) async {
    final session = McTestSession.current..backend.useFixtureSet(thingsSet);
    await initFlow(tester, thingsFlow);
    await mcSettle(tester);
    await session.monitoring.trackEvent('seen');
    expect(session.monitoring.events.single.name, 'seen');
  });
}
