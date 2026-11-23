import 'package:dio/dio.dart';

/// Retries idempotent requests that failed in a way a second try can fix:
/// connect timeouts, no connection and 5xx. A POST or PATCH is never
/// retried, since the first attempt may have been applied. A receive timeout
/// is not retried either (it would stall for a full receive timeout per
/// attempt), nor is a request whose body is a stream (it cannot be replayed).
/// [retries] is the number of extra attempts, so 2 means at most 3 in total.
///
/// When every attempt fails, the caller gets the last failure; when a retry
/// cannot even be set up, the original failure.
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

  /// Wait before attempt n (1-based): `retryDelay * n`. Cancelling the
  /// request's `CancelToken` ends the wait.
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
        !_replayable(options.data) ||
        !_retryable(err)) {
      return handler.next(err);
    }
    var last = err;
    for (var attempt = 1; attempt <= retries; attempt++) {
      final token = options.cancelToken;
      if (retryDelay > Duration.zero) {
        final wait = Future<void>.delayed(retryDelay * attempt);
        await (token == null
            ? wait
            : Future.any<void>([wait, token.whenCancel]));
      }
      if (token != null && token.isCancelled) {
        return handler.next(
          DioException.requestCancelled(
            requestOptions: options,
            reason: token.cancelError?.error,
          ),
        );
      }
      try {
        final response = await _dio.fetch<Object?>(
          options.copyWith(
            // A FormData is single-use: each attempt gets its own copy.
            data: options.data is FormData
                ? (options.data as FormData).clone()
                : options.data,
            extra: {...options.extra, _retrying: true},
          ),
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

  static bool _replayable(Object? data) => data is! Stream;

  static bool _retryable(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => (e.response?.statusCode ?? 0) >= 500,
    _ => false,
  };
}
