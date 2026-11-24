import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:mc_test_utils/src/session.dart';

/// An external dependency a feature test replaces: a clock, a navigator
/// contract, a service another package owns. Registered as [T] in the root
/// container. The bloc, repository and API of the feature are never doubled.
final class ExternalDouble<T extends Object> {
  const ExternalDouble(this.instance);

  final T instance;

  McDIInitializer toInitializer() => McDIInitializer(
    (GetIt getIt, String? _) => getIt.registerSingleton<T>(instance),
  );
}

/// The test root container (Tide's `TestContainer`, TD-02).
///
/// It mirrors the production root list of `app_core`'s `rootInitializers`
/// (config, monitoring, storage, mocked backend, API client, event bus), with
/// doubles only at the edges: `MockMonitoring`, the session's
/// `McBackendHarness` transport, a temporary storage directory and a fixed
/// config. The real `Dio` with its interceptors runs over the harness.
///
/// A utility cannot import `app_core` (layering), so the list is repeated here;
/// F-0022 records how drift is guarded.
abstract final class McTestContainer {
  /// The `AppConfig` tests run on: seed 42, no latency, the happy scenario.
  static const AppConfig config = AppConfig(
    env: 'test',
    backend: BackendConfig(seed: 42, latency: Duration.zero, scenario: 'happy'),
    apiBaseUrl: 'https://mock.mini-client.invalid',
    build: 'test',
  );

  /// The initializers, root list first, then [wirings] and [externals].
  static List<McDIInitializer> initializers(
    McTestSession session, {
    List<McDIInitializer> wirings = const [],
    List<ExternalDouble<Object>> externals = const [],
  }) => [
    McDIInitializer((getIt, _) => getIt.registerSingleton<AppConfig>(config)),
    McDIInitializer(
      (getIt, _) => getIt.registerSingleton<Monitoring>(session.monitoring),
    ),
    StorageDIInitializer(session.storageDirectory),
    McDIInitializer(
      (getIt, _) =>
          getIt.registerSingleton<MockBackend>(session.backend.backend),
    ),
    ApiClientDIInitializer(
      adapter: session.backend.adapter,
      // No retry delay: a timer would need a pump, and the retry itself is
      // what the tests observe.
      retryDelay: Duration.zero,
    ),
    const EventBusDIInitializer(),
    ...wirings,
    for (final external in externals) external.toInitializer(),
  ];

  /// Publishes the test root container for [session], once per test.
  static Future<DIContainer> initialize(
    McTestSession session, {
    List<McDIInitializer> wirings = const [],
    List<ExternalDouble<Object>> externals = const [],
  }) async {
    if (session.containerInitialized) {
      throw StateError(
        'The test container is already initialised for this test. Pass '
        'externals to the first initFlow or McTestContainer.initialize call.',
      );
    }
    session.containerInitialized = true;
    return await initializeDIContainer(
      initializers(session, wirings: wirings, externals: externals),
    );
  }

  /// The shared `Dio`, as a feature's repository gets it.
  static Dio get dio => diContainer<Dio>();
}
