import 'package:dio/dio.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Logs one line per attempt to [Monitoring]: method, path and status or
/// failure type. Never bodies or headers (they can carry tokens).
///
/// [Monitoring] is resolved per call, so it may be registered after the
/// client; if it never is, the first request fails loudly.
class MonitoringInterceptor extends Interceptor {
  MonitoringInterceptor(this._monitoring);

  final Monitoring Function() _monitoring;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler h) {
    _monitoring().log(
      '${_what(response.requestOptions)} -> ${response.statusCode}',
      level: LogLevel.debug,
    );
    h.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    _monitoring().log(
      '${_what(err.requestOptions)} failed: '
      '${status ?? err.type.name}',
      level: LogLevel.warning,
    );
    handler.next(err);
  }

  static String _what(RequestOptions o) => '${o.method} ${o.uri.path}';
}
