import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_appearance/src/appearance.dart';
import 'package:mc_appearance/src/appearance_ports.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

/// Registers [Appearance] (also as [AppearanceReader] and
/// [AppearanceSettings]) with the device's saved preferences, read
/// synchronously, then starts following the session. **It never waits for
/// the network**: a signed-in launch shows the device's copy at once and the
/// account's copy when it arrives.
///
/// List `MonitoringDIInitializer`, `StorageDIInitializer`,
/// `SessionDIInitializer`, `ApiClientDIInitializer` and
/// `ApiAuthDIInitializer` first: the sync goes through the shared `Dio`, so
/// it carries the bearer, and the session says whose preferences these are.
class AppearanceDIInitializer extends McDIInitializer {
  const AppearanceDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {
    final appearance = Appearance.open(
      dio: getIt<Dio>(),
      session: getIt<SessionReader>(),
      store: getIt<FileStore>(),
      monitoring: getIt<Monitoring>(),
    );
    getIt
      ..registerSingleton<Appearance>(
        appearance,
        dispose: (a) => a.dispose(),
      )
      ..registerSingleton<AppearanceReader>(appearance)
      ..registerSingleton<AppearanceSettings>(appearance);
    appearance.start();
  }
}
