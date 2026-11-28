import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:settings_home/src/di/di_initializer.dart';
import 'package:settings_home/src/di/flow_scope.dart';
import 'package:settings_home/src/domain/settings_home_analytics.dart';
import 'package:settings_home/src/flow/settings_home_flow_state.dart';
import 'package:settings_home/src/l10n/settings_home_l10n.dart';
import 'package:settings_home/src/navigator/settings_home_navigator.dart';
import 'package:settings_home/src/presentation/page/settings_home_page.dart';

/// The feature's only entry point (R4): the settings index. Account (who is
/// signed in, Sign in / Sign out), Appearance (opens the appearance settings
/// with the current theme as its subtitle) and About (version, build and the
/// mocked backend's seed).
///
/// The app builds it from `/settings` (account_wiring) with the navigator
/// implementation from its wiring; tests pass a mock. `/settings/appearance`
/// is nested under it, so Back from Appearance lands here.
///
/// Its one page is the screen `settings_home`, tracked from inside the flow by
/// `AnalyticsFlowObserver` (ADR-0012).
///
/// Immutable after creation: the flow reads [navigator] once, when its
/// scope opens.
class SettingsHomeFlow extends StatelessWidget {
  const SettingsHomeFlow({required this.navigator, super.key});

  final SettingsHomeNavigator navigator;

  @override
  Widget build(BuildContext context) => FeatureFlow<SettingsHomeFlowState>(
    flowInitializer: const SettingsHomeDIInitializer(),
    rootImports: settingsHomeRootImports,
    provide: (scope) =>
        scope.registerSingleton<SettingsHomeNavigator>(navigator),
    localizationsDelegates: const [SettingsHomeL10n.delegate],
    // The flow's page is a screen: resolved inside the flow, without a
    // dependency on the host route (F-0056 §4).
    observers: [
      AnalyticsFlowObserver(
        (context) => context.di<AnalyticsTracker>(),
        host: (context) => FlowScope.read(context).outerRoute,
      ),
    ],
    state: const SettingsHomeFlowState(),
    onGeneratePages: (state) => const [
      McFlowPage(name: settingsHomeScreen, child: SettingsHomePage()),
    ],
  );
}
