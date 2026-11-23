import 'canonical_json.dart';

/// A request as handlers see it: no Dio types.
final class MockRequest {
  const MockRequest({
    required this.method,
    required this.path,
    this.query = const {},
    this.headers = const {},
    this.body,
  });

  /// Upper-case HTTP method.
  final String method;

  /// The URL path without the query, e.g. `/v1/characters`.
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;

  /// The decoded JSON body, if any.
  final Object? body;

  String get routeKey => '$method $path';
}

/// A handler's answer. [body] is JSON-encodable data.
final class MockResponse {
  const MockResponse(this.status, [this.body]);

  const MockResponse.ok(Object? body) : this(200, body);

  /// A JSON error body shaped `{"error": {"code", "message", ...}}`.
  factory MockResponse.error(
    int status,
    String code,
    String message, {
    Map<String, Object?> extra = const {},
  }) => MockResponse(status, {
    'error': {'code': code, 'message': message, ...extra},
  });

  final int status;
  final Object? body;

  String encode() => body == null ? '' : canonicalJson(body);
}
