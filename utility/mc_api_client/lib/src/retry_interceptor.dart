import 'package:dio/dio.dart';

/// Retries idempotent requests that failed in a way a second try can fix:
/// timeouts, no connection and 5xx. A POST or PATCH is never retried, since
/// the first attempt may have been applied. [retries] is the number of extra
/// attempts, so 2 means at most 3 in total.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.retries = 2,
    this.retryDelay = const Duration(milliseconds: 200),
  });

  static const _idempotent = {'GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS'};
  static const _retrying = 'mc_api_client.retrying';

  final Dio _dio;
  final int retries;

  /// Wait before attempt n (1-based): `retryDelay * n`.
  final Duration retryDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    // Attempts made by the loop below fail straight through.
    if (options.extra[_retrying] == true ||
        retries <= 0 ||
        !_idempotent.contains(options.method.toUpperCase()) ||
        !_retryable(err)) {
      return handler.next(err);
    }
    var last = err;
    for (var attempt = 1; attempt <= retries; attempt++) {
      if (retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay * attempt);
      }
      try {
        final response = await _dio.fetch<Object?>(
          options.copyWith(extra: {...options.extra, _retrying: true}),
        );
        return handler.resolve(response);
      } on DioException catch (e) {
        last = e;
        if (!_retryable(e)) {
          break;
        }
      }
    }
    return handler.next(last);
  }

  static bool _retryable(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => (e.response?.statusCode ?? 0) >= 500,
    _ => false,
  };
}
