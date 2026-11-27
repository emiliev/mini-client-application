import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flags/src/feature_flag_overrides.dart';
import 'package:mc_feature_flags/src/feature_flags.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

/// Registers [FeatureFlags] (also as [FeatureFlagsReader] and
/// [FeatureFlagOverrides]) with the saved values, then starts the first fetch
/// in the background. **It never waits for the network**: the registration is
/// done before the fetch has begun, so boot reaches the app with cached or
/// default values.
///
/// List `ConfigDIInitializer`, `MonitoringDIInitializer`, `StorageDIInitializer`,
/// `SessionDIInitializer`, `ApiClientDIInitializer` and `ApiAuthDIInitializer`
/// first (plan 01 §3.4): the fetch goes through the shared `Dio`, so it
/// carries the bearer, and the session gives it the epoch. `mc_monitoring` and
/// `mc_session` are dependencies of this package for exactly these reasons:
/// monitoring receives the one report of a wrong-typed remote value, and the
/// session says whose flags these are and when they stop being valid.
class FeatureFlagsDIInitializer extends McDIInitializer {
  const FeatureFlagsDIInitializer() : super(_init);

  static Future<void> _init(GetIt getIt, String? environment) async {
    final flags = await FeatureFlags.open(
      dio: getIt<Dio>(),
      session: getIt<SessionReader>(),
      store: getIt<FileStore>(),
      env: getIt<AppConfig>().env,
      monitoring: getIt<Monitoring>(),
    );
    getIt
      ..registerSingleton<FeatureFlags>(flags, dispose: (f) => f.dispose())
      ..registerSingleton<FeatureFlagsReader>(flags)
      ..registerSingleton<FeatureFlagOverrides>(flags);
    flags.start();
  }
}
