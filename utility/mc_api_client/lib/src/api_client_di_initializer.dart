import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_client/src/api_dio.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Registers the one shared [Dio], whose adapter is the mocked [backend]
/// (ADR-0005). The base URL is `AppConfig.apiBaseUrl` unless [baseUrl]
/// overrides it, so list `ConfigDIInitializer` first (or pass [baseUrl]).
/// [Monitoring] is resolved on each request, so `MonitoringDIInitializer`
/// must be registered by then; a missing one fails the request loudly.
class ApiClientDIInitializer extends McDIInitializer {
  ApiClientDIInitializer({
    required MockBackend backend,
    String? baseUrl,
    int retries = 2,
    Duration retryDelay = const Duration(milliseconds: 200),
  }) : super(_init(backend, baseUrl, retries, retryDelay));

  static GetItInitializer _init(
    MockBackend backend,
    String? baseUrl,
    int retries,
    Duration retryDelay,
  ) => (GetIt getIt, String? environment) {
    getIt.registerSingleton<Dio>(
      createApiDio(
        adapter: backend.adapter,
        baseUrl: baseUrl ?? getIt<AppConfig>().apiBaseUrl,
        retries: retries,
        retryDelay: retryDelay,
        monitoring: () => getIt<Monitoring>(),
      ),
    );
  };
}
