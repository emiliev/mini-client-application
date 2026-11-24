import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// Wires the in-process backend (D5, plan 01 §5): a [MockBackend] built from
/// `AppConfig.backend` and the app's [Dio], whose adapter is the backend.
/// Features only ever see `Dio`. Must run after `ConfigDIInitializer`.
class MockedBackendDIInitializer extends McDIInitializer {
  MockedBackendDIInitializer({List<MockDomain> domains = const []})
    : super(_init(domains));

  static GetItInitializer _init(List<MockDomain> domains) =>
      (GetIt getIt, String? environment) {
        final config = getIt<AppConfig>().backend;
        final backend = MockBackend(
          seed: config.seed,
          latency: config.latency == Duration.zero
              ? LatencyProfile.none
              : LatencyProfile.realistic(
                  base: config.latency,
                  jitter: Duration.zero,
                ),
          domains: domains,
        );
        // "happy" (and any name no domain declares) means no scenario.
        if (backend.scenarioNames.contains(config.scenario)) {
          backend.useScenario(config.scenario);
        }
        getIt
          ..registerSingleton<MockBackend>(backend)
          ..registerSingleton<Dio>(
            backend.createDio(),
            dispose: (dio) => dio.close(force: true),
          );
      };
}
