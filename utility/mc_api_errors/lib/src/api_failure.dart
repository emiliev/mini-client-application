import 'package:dio/dio.dart';

/// Why a call to the backend failed. A sealed family so a feature maps each
/// case to its own state with an exhaustive `switch`.
sealed class ApiFailure implements Exception {
  const ApiFailure(this.message);

  /// Maps whatever was thrown. A [DioException] maps by type and status; a
  /// [FormatException] (or a Dio error wrapping one) is [ApiMalformed]; every
  /// other throwable, a `TypeError` from a bad JSON shape included, is
  /// [ApiUnexpected] with its message kept.
  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) {
      return error;
    }
    if (error is DioException) {
      return _fromDio(error);
    }
    if (error is FormatException) {
      return ApiMalformed(error.toString());
    }
    return ApiUnexpected('${error.runtimeType}: $error');
  }

  const factory ApiFailure.timeout([String message]) = ApiTimeout;
  const factory ApiFailure.offline([String message]) = ApiOffline;
  const factory ApiFailure.unauthorized([String message]) = ApiUnauthorized;
  const factory ApiFailure.notFound([String message]) = ApiNotFound;
  const factory ApiFailure.clientError(int status, [String message]) =
      ApiClientError;
  const factory ApiFailure.server(int status, [String message]) = ApiServer;
  const factory ApiFailure.malformed([String message]) = ApiMalformed;
  const factory ApiFailure.unexpected([String message]) = ApiUnexpected;

  final String message;

  static ApiFailure _fromDio(DioException e) {
    final detail = e.message ?? e.error?.toString() ?? e.type.name;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiTimeout(detail);
      case DioExceptionType.connectionError:
        return ApiOffline(detail);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 401) {
          return ApiUnauthorized(detail);
        }
        if (status == 404) {
          return ApiNotFound(detail);
        }
        if (status >= 500) {
          return ApiServer(status, detail);
        }
        if (status >= 400) {
          return ApiClientError(status, detail);
        }
        return ApiUnexpected('HTTP $status: $detail');
      case DioExceptionType.cancel:
        return ApiUnexpected('Request cancelled: $detail');
      case DioExceptionType.badCertificate:
        return ApiUnexpected('Bad certificate: $detail');
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is FormatException) {
          return ApiMalformed(inner.toString());
        }
        if (inner is ApiFailure) {
          return inner;
        }
        return ApiUnexpected(
          inner == null ? detail : '${inner.runtimeType}: $inner',
        );
    }
  }

  @override
  String toString() => '$runtimeType($message)';
}

final class ApiTimeout extends ApiFailure {
  const ApiTimeout([super.message = 'The request timed out']);
}

final class ApiOffline extends ApiFailure {
  const ApiOffline([super.message = 'No network connection']);
}

final class ApiUnauthorized extends ApiFailure {
  const ApiUnauthorized([super.message = 'Unauthorized']);
}

final class ApiNotFound extends ApiFailure {
  const ApiNotFound([super.message = 'Not found']);
}

/// Any 4xx other than 401 and 404 (400, 403, 409, 422, 429, ...).
final class ApiClientError extends ApiFailure {
  const ApiClientError(this.status, [super.message = 'Request rejected']);

  final int status;
}

final class ApiServer extends ApiFailure {
  const ApiServer(this.status, [super.message = 'Server error']);

  final int status;
}

final class ApiMalformed extends ApiFailure {
  const ApiMalformed([super.message = 'Malformed response']);
}

final class ApiUnexpected extends ApiFailure {
  const ApiUnexpected([super.message = 'Unexpected error']);
}
