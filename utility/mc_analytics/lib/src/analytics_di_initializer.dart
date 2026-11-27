import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_analytics/src/analytics.dart';
import 'package:mc_analytics/src/consent.dart';
import 'package:mc_analytics/src/consent_store.dart';
import 'package:mc_analytics/src/lifecycle_observer.dart';
import 'package:mc_analytics/src/sinks.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';

/// Registers [Analytics]. List `ConfigDIInitializer`, `MonitoringDIInitializer`
/// and `StorageDIInitializer` first.
///
/// The starting consent is the saved choice, else the config's
/// `analytics.defaultConsent` (`granted` in `dev` and `e2e` so developers see
/// events, absent, so `unknown`, in release-like builds). The default sink is
/// `MonitoringAnalyticsSink`: no data leaves the device (P-004). The app's
/// lifecycle is observed for sessions unless [observeLifecycle] is false.
class AnalyticsDIInitializer extends McDIInitializer {
  AnalyticsDIInitializer({
    List<AnalyticsSink>? sinks,
    Random? random,
    AnalyticsClock? clock,
    bool? debugMode,
    WidgetsBinding? binding,
    bool observeLifecycle = true,
  }) : super(
         _init(
           sinks: sinks,
           random: random,
           clock: clock,
           debugMode: debugMode,
           binding: binding,
           observeLifecycle: observeLifecycle,
         ),
       );

  static GetItInitializer _init({
    required List<AnalyticsSink>? sinks,
    required Random? random,
    required AnalyticsClock? clock,
    required bool? debugMode,
    required WidgetsBinding? binding,
    required bool observeLifecycle,
  }) => (GetIt getIt, String? environment) async {
    final monitoring = getIt<Monitoring>();
    final store = ConsentStore(getIt<FileStore>());
    final fallback = AnalyticsConsent.parse(
      getIt<AppConfig>().analytics.defaultConsent,
    );
    final analytics = Analytics(
      sinks: sinks ?? [MonitoringAnalyticsSink(monitoring)],
      monitoring: monitoring,
      consent: await store.restore(fallback),
      persist: store.save,
      random: random,
      clock: clock,
      debugMode: debugMode,
    );
    final widgets = observeLifecycle
        ? (binding ?? WidgetsBinding.instance)
        : null;
    final observer = AnalyticsLifecycleObserver(analytics);
    getIt.registerSingleton<Analytics>(
      analytics,
      dispose: (a) {
        widgets?.removeObserver(observer);
        a.dispose();
      },
    );
    // Only after registering: a registration that throws (a second
    // initializer) leaves no observer behind that nothing would remove.
    widgets?.addObserver(observer);
  };
}
