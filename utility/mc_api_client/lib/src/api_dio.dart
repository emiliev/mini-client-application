import 'package:dio/dio.dart';
import 'package:mc_api_client/src/logging_interceptor.dart';
import 'package:mc_api_client/src/retry_interceptor.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The placeholder host used when no real backend exists. The mocked
/// backend never contacts it.
const String defaultApiBaseUrl = 'https://mock.mini-client.invalid';

/// Builds the shared [Dio]: base URL, timeouts, one log line per attempt
/// (when [monitoring] is given; it is resolved on each request) and retry for idempotent requests.
///
/// Interceptor order matters: logging sits before retry so each attempt is
/// logged once, the first by the outer call and the rest by the retries.
Dio createApiDio({
  required HttpClientAdapter adapter,
  String baseUrl = defaultApiBaseUrl,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 30),
  int retries = 2,
  Duration retryDelay = const Duration(milliseconds: 200),
  Monitoring Function()? monitoring,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    ),
  )..httpClientAdapter = adapter;
  if (monitoring != null) {
    dio.interceptors.add(MonitoringInterceptor(monitoring));
  }
  dio.interceptors.add(
    RetryInterceptor(dio, retries: retries, retryDelay: retryDelay),
  );
  return dio;
}
