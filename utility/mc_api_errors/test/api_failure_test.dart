import 'package:dio/dio.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:test/test.dart';

DioException _bad(int status) => DioException.badResponse(
  statusCode: status,
  requestOptions: RequestOptions(path: '/x'),
  response: Response<Object?>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
  ),
);

void main() {
  test('T-0023-AC3: a TypeError is unexpected and keeps its message', () {
    Object? thrown;
    try {
      // A bad JSON shape: a String where a Map is expected.
      final Object body = 'not a map';
      (body as Map<String, Object?>)['id'];
    } catch (e) {
      thrown = e;
    }
    expect(thrown, isA<TypeError>());
    final failure = ApiFailure.from(thrown!);
    expect(failure, isA<ApiUnexpected>());
    expect(failure.message, contains('$thrown'));
  });

  test('T-0023-AC1: Dio types and statuses map to the matching failure', () {
    final ro = RequestOptions(path: '/x');
    expect(
      ApiFailure.from(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: ro,
        ),
      ),
      isA<ApiTimeout>(),
    );
    expect(
      ApiFailure.from(
        DioException.connectionError(
          requestOptions: ro,
          reason: 'down',
        ),
      ),
      isA<ApiOffline>(),
    );
    expect(ApiFailure.from(_bad(401)), isA<ApiUnauthorized>());
    expect(ApiFailure.from(_bad(404)), isA<ApiNotFound>());
    expect(
      ApiFailure.from(_bad(503)),
      isA<ApiServer>().having((f) => f.status, 'status', 503),
    );
    expect(
      ApiFailure.from(
        DioException(requestOptions: ro, error: const FormatException('bad')),
      ),
      isA<ApiMalformed>(),
    );
  });

  test('an ApiFailure passes through unchanged', () {
    const f = ApiFailure.offline();
    expect(identical(ApiFailure.from(f), f), isTrue);
  });
}
