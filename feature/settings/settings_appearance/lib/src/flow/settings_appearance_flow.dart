import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:settings_appearance/src/di/di_initializer.dart';
import 'package:settings_appearance/src/di/flow_scope.dart';
import 'package:settings_appearance/src/domain/settings_analytics.dart';
import 'package:settings_appearance/src/flow/settings_appearance_flow_state.dart';
import 'package:settings_appearance/src/l10n/settings_appearance_l10n.dart';
import 'package:settings_appearance/src/navigator/settings_appearance_navigator.dart';
import 'package:settings_appearance/src/presentation/page/about_themes_page.dart';
import 'package:settings_appearance/src/presentation/page/appearance_page.dart';

/// The feature's only entry point (R4): the appearance settings (theme mode,
/// density, reduce motion), with the "About themes" explainer inside the
/// flow. The values themselves are app-wide (`mc_appearance`, ADR-0013):
/// the screen changes them, and the whole app follows.
///
/// The app builds it from `/settings/appearance` (account_wiring) with the
/// navigator implementation from its wiring; tests pass a mock.
///
/// Its two pages are screens: `settings_appearance` and
/// `settings_appearance_about`, tracked from inside the flow by
/// `AnalyticsFlowObserver` (ADR-0012).
///
/// Immutable after creation: the flow reads [navigator] once, when its
/// scope opens.
class SettingsAppearanceFlow extends StatelessWidget {
  const SettingsAppearanceFlow({required this.navigator, super.key});

  final SettingsAppearanceNavigator navigator;

  @override
  Widget build(BuildContext context) =>
      FeatureFlow<SettingsAppearanceFlowState>(
        flowInitializer: const SettingsAppearanceDIInitializer(),
        rootImports: settingsAppearanceRootImports,
        provide: (scope) =>
            scope.registerSingleton<SettingsAppearanceNavigator>(navigator),
        localizationsDelegates: const [SettingsAppearanceL10n.delegate],
        // The flow's pages are screens: resolved inside the flow, without a
        // dependency on the host route (F-0056 §4).
        observers: [
          AnalyticsFlowObserver(
            (context) => context.di<AnalyticsTracker>(),
            host: (context) => FlowScope.read(context).outerRoute,
          ),
        ],
        state: const SettingsAppearanceFlowState(),
        onGeneratePages: (state) => [
          const McFlowPage(
            name: settingsAppearanceScreen,
            child: AppearancePage(),
          ),
          if (state.aboutOpen)
            const McFlowPage(
              name: settingsAppearanceAboutScreen,
              child: AboutThemesPage(),
            ),
        ],
      );
}
