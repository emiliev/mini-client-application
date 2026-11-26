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
      ApiFailure.from(_bad(422)),
      isA<ApiClientError>().having((f) => f.status, 'status', 422),
    );
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

  group('T-0048-AC2 a 4xx keeps the code and parameter of its error body', () {
    DioException rejected(int status, Object? data) => DioException.badResponse(
      statusCode: status,
      requestOptions: RequestOptions(path: '/x'),
      response: Response<Object?>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: data,
      ),
    );

    test('T-0048-AC2 a map body', () {
      final failure = ApiFailure.from(
        rejected(400, {
          'error': {
            'code': 'duplicate_name',
            'message': 'taken',
            'parameter': 'name',
          },
        }),
      );
      expect(failure, isA<ApiClientError>());
      final error = failure as ApiClientError;
      expect(error.status, 400);
      expect(error.code, 'duplicate_name');
      expect(error.parameter, 'name');
    });

    test('T-0048-AC2 a JSON text body, and a body without a parameter', () {
      final error = ApiFailure.from(
        rejected(409, '{"error": {"code": "conflict", "message": "x"}}'),
      ) as ApiClientError;
      expect(error.status, 409);
      expect(error.code, 'conflict');
      expect(error.parameter, isNull);
    });

    test('T-0048-AC2 a body off that shape leaves both null', () {
      for (final data in <Object?>[
        null,
        'not json',
        '[1, 2]',
        {'error': 'flat'},
        {
          'error': {'code': 7},
        },
        {
          'error': {'code': 'x', 'parameter': 3},
        },
      ]) {
        final error = ApiFailure.from(rejected(400, data)) as ApiClientError;
        expect(
          error.code,
          data is Map &&
                  data['error'] is Map &&
                  (data['error'] as Map)['code'] == 'x'
              ? 'x'
              : isNull,
          reason: '$data',
        );
        expect(error.parameter, isNull, reason: '$data');
      }
    });

    test('T-0048-AC2 the plain constructor has no body', () {
      const error = ApiFailure.clientError(400, 'rejected') as ApiClientError;
      expect(error.code, isNull);
      expect(error.parameter, isNull);
    });
  });

  test('an ApiFailure passes through unchanged', () {
    const f = ApiFailure.offline();
    expect(identical(ApiFailure.from(f), f), isTrue);
  });

  // T-0048-AC8: the package is now under the coverage gate (it changed for
  // T-0048); these are the mappings no test exercised before.
  group('T-0048-AC8 the other Dio outcomes', () {
    final ro = RequestOptions(path: '/x');

    test('T-0048-AC8 a plain FormatException is malformed', () {
      expect(
        ApiFailure.from(const FormatException('bad json')),
        isA<ApiMalformed>(),
      );
    });

    test('T-0048-AC8 cancel, bad certificate and a status below 400', () {
      expect(
        ApiFailure.from(
          DioException.requestCancelled(requestOptions: ro, reason: 'x'),
        ),
        isA<ApiUnexpected>().having(
          (f) => f.message,
          'message',
          contains('cancelled'),
        ),
      );
      expect(
        ApiFailure.from(DioException.badCertificate(requestOptions: ro)),
        isA<ApiUnexpected>().having(
          (f) => f.message,
          'message',
          contains('certificate'),
        ),
      );
      expect(
        ApiFailure.from(_bad(302)),
        isA<ApiUnexpected>().having(
          (f) => f.message,
          'message',
          contains('HTTP 302'),
        ),
      );
    });

    test('T-0048-AC8 an unknown error: its inner failure, or its text', () {
      const inner = ApiFailure.offline();
      expect(
        identical(
          ApiFailure.from(DioException(requestOptions: ro, error: inner)),
          inner,
        ),
        isTrue,
      );
      expect(
        ApiFailure.from(
          DioException(requestOptions: ro, error: StateError('boom')),
        ),
        isA<ApiUnexpected>().having(
          (f) => f.message,
          'message',
          contains('boom'),
        ),
      );
      expect(
        ApiFailure.from(DioException(requestOptions: ro, message: 'no inner')),
        isA<ApiUnexpected>().having((f) => f.message, 'message', 'no inner'),
      );
    });

    test('T-0048-AC8 toString names the type and the message', () {
      expect('${const ApiFailure.timeout('slow')}', 'ApiTimeout(slow)');
    });
  });
}
