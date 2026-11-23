import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_client/src/api_dio.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Registers the one shared [Dio], whose adapter is the mocked [backend]
/// (ADR-0005). Uses [Monitoring] when an earlier initializer registered it,
/// so list `MonitoringDIInitializer` first.
class ApiClientDIInitializer extends McDIInitializer {
  ApiClientDIInitializer({
    required MockBackend backend,
    String baseUrl = defaultApiBaseUrl,
    int retries = 2,
    Duration retryDelay = const Duration(milliseconds: 200),
  }) : super(_init(backend, baseUrl, retries, retryDelay));

  static GetItInitializer _init(
    MockBackend backend,
    String baseUrl,
    int retries,
    Duration retryDelay,
  ) => (GetIt getIt, String? environment) {
    getIt.registerSingleton<Dio>(
      createApiDio(
        adapter: backend.adapter,
        baseUrl: baseUrl,
        retries: retries,
        retryDelay: retryDelay,
        monitoring: getIt.isRegistered<Monitoring>()
            ? getIt<Monitoring>()
            : null,
      ),
    );
  };
}
