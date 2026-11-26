import 'dart:convert';

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
          final body = _errorBody(e.response?.data);
          return ApiClientError(status, detail, body?.code, body?.parameter);
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

  /// The `{"error": {"code", "parameter", ...}}` body the mocked backend's
  /// domains send with a `4xx`, as a map or as JSON text; null for any other
  /// body.
  static ({String code, String? parameter})? _errorBody(Object? data) {
    Object? decoded = data;
    if (data is String) {
      try {
        decoded = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    final error = decoded is Map ? decoded['error'] : null;
    if (error is! Map || error['code'] is! String) {
      return null;
    }
    final parameter = error['parameter'];
    return (
      code: error['code'] as String,
      parameter: parameter is String ? parameter : null,
    );
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
///
/// [code] and [parameter] come from the response's error body
/// (`{"error": {"code": "invalid_name", "parameter": "name"}}`), so a feature
/// can show a server-side validation error under the field it names (T-0048);
/// both are null when the body has no such shape.
final class ApiClientError extends ApiFailure {
  const ApiClientError(
    this.status, [
    super.message = 'Request rejected',
    this.code,
    this.parameter,
  ]);

  final int status;

  /// The body's `error.code` (`invalid_name`, `duplicate_name`, ...).
  final String? code;

  /// The body's `error.parameter`: the request field the error is about.
  final String? parameter;
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
