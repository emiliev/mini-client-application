import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The scenario name for "no injected failures" (`backend.scenario`).
const String happyScenario = 'happy';

/// The adapter `ApiClientDIInitializer` gets in the root list. The backend
/// is built from `AppConfig` during boot, after the list is created, so this
/// forwards to whichever [MockBackend] the current boot attempt built.
class MockBackendHttpAdapter implements HttpClientAdapter {
  HttpClientAdapter? _target;

  /// The adapter requests go to, or null before the backend is built.
  HttpClientAdapter? get target => _target;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final target = _target;
    if (target == null) {
      throw StateError(
        'No mocked backend is wired yet: MockedBackendDIInitializer must run '
        'before the first request.',
      );
    }
    return target.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _target?.close(force: force);
}

/// Builds the in-process backend (D5, plan 01 §5) from `AppConfig.backend`,
/// registers it, and points [adapter] at it. Features only ever see the
/// `Dio` that `ApiClientDIInitializer` registers over [adapter]. Must run
/// after `ConfigDIInitializer`.
class MockedBackendDIInitializer extends McDIInitializer {
  MockedBackendDIInitializer({
    required MockBackendHttpAdapter adapter,
    List<MockDomain> domains = const [],
  }) : super(_init(adapter, domains));

  static GetItInitializer _init(
    MockBackendHttpAdapter adapter,
    List<MockDomain> domains,
  ) => (GetIt getIt, String? environment) {
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
    // "happy" means no scenario; any other name must be one a domain declares.
    if (config.scenario != happyScenario) {
      if (!backend.scenarioNames.contains(config.scenario)) {
        final known = [
          happyScenario,
          ...backend.scenarioNames.toList()..sort(),
        ];
        throw StateError(
          'Unknown backend.scenario "${config.scenario}" in app_config.json. '
          'Known: ${known.join(', ')}.',
        );
      }
      backend.useScenario(config.scenario);
    }
    getIt.registerSingleton<MockBackend>(backend);
    adapter._target = backend.adapter;
  };
}
