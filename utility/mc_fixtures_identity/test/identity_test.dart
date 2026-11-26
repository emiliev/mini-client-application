import 'package:dio/dio.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:test/test.dart';

const _reader = 'reader@mini-client.test';
const _password = 'marvelous';

MockBackend _backend([MockDomain domain = const IdentityMockDomain()]) =>
    MockBackend(domains: [domain]);

Dio _dio(MockBackend backend) =>
    backend.createDio()..options.validateStatus = (_) => true;

Future<Map<String, Object?>> _signIn(
  Dio dio, {
  String email = _reader,
  String password = _password,
}) async {
  final response = await dio.post<Map<String, Object?>>(
    '/v1/auth/sign-in',
    data: {'email': email, 'password': password},
  );
  expect(response.statusCode, 200);
  return response.data!;
}

Options _bearer(String token) =>
    Options(headers: {'Authorization': 'Bearer $token'});

void main() {
  group('T-0039-AC3 sign-in', () {
    test('T-0039-AC3 a fixture user signs in and gets tokens', () async {
      final body = await _signIn(_dio(_backend()));

      expect(body['user'], {
        'id': 'u-100',
        'email': _reader,
        'displayName': 'Rhea Reader',
      });
      expect(body['accessToken'], 'mc-access-u-100-1');
      expect(body['refreshToken'], 'mc-refresh-u-100-1');
      expect(body['tokenType'], 'Bearer');
      expect(body['expiresIn'], 900);
    });

    test('T-0039-AC3 the email is case-insensitive', () async {
      final body = await _signIn(
        _dio(_backend()),
        email: '  Reader@Mini-Client.TEST ',
      );

      expect((body['user']! as Map)['id'], 'u-100');
    });

    test('T-0039-AC3 a wrong password or unknown email is 401', () async {
      final dio = _dio(_backend());

      for (final (email, password) in [
        (_reader, 'nope'),
        ('nobody@mini-client.test', _password),
      ]) {
        final response = await dio.post<Map<String, Object?>>(
          '/v1/auth/sign-in',
          data: {'email': email, 'password': password},
        );
        expect(response.statusCode, 401);
        expect(
          response.data!['error'],
          containsPair('code', 'invalid_credentials'),
        );
        expect(response.data.toString(), isNot(contains('accessToken')));
      }
    });

    test('T-0039-AC3 a body that is not {email, password} is 400', () async {
      final dio = _dio(_backend());

      for (final data in <Object?>[
        null,
        'text',
        {'email': _reader},
      ]) {
        final response = await dio.post<Map<String, Object?>>(
          '/v1/auth/sign-in',
          data: data,
        );
        expect(response.statusCode, 400, reason: '$data');
        expect(response.data!['error'], containsPair('code', 'invalid_body'));
      }
    });
  });

  group('T-0039-AC3 tokens', () {
    test('T-0039-AC3 /v1/me needs a valid bearer', () async {
      final dio = _dio(_backend());
      final tokens = await _signIn(dio);

      final ok = await dio.get<Map<String, Object?>>(
        '/v1/me',
        options: _bearer(tokens['accessToken']! as String),
      );
      expect(ok.statusCode, 200);
      expect(ok.data, {
        'id': 'u-100',
        'email': _reader,
        'displayName': 'Rhea Reader',
        'favouriteCount': 2,
      });

      for (final header in <String?>[
        null,
        'Bearer mc-access-u-100-expired',
        'Bearer mc-access-u-999-1',
        'Bearer garbage',
        'Basic mc-access-u-100-1',
      ]) {
        final response = await dio.get<Map<String, Object?>>(
          '/v1/me',
          options: Options(headers: {'Authorization': ?header}),
        );
        expect(response.statusCode, 401, reason: '$header');
        expect(
          response.data!['error'],
          containsPair('code', 'unauthenticated'),
        );
      }
    });

    test('T-0039-AC3 refresh rotates: a token works once', () async {
      final dio = _dio(_backend());
      final first = await _signIn(dio);

      final response = await dio.post<Map<String, Object?>>(
        '/v1/auth/refresh',
        data: {'refreshToken': first['refreshToken']},
      );
      expect(response.statusCode, 200);
      expect(response.data!['accessToken'], 'mc-access-u-100-2');
      expect(response.data!['refreshToken'], 'mc-refresh-u-100-2');

      final again = await dio.post<Map<String, Object?>>(
        '/v1/auth/refresh',
        data: {'refreshToken': first['refreshToken']},
      );
      expect(again.statusCode, 401);
      expect(
        again.data!['error'],
        containsPair('code', 'invalid_refresh_token'),
      );
    });

    test(
      'T-0039-AC3 a refresh token saved by an earlier run still works once',
      () async {
        // The backend starts empty on every launch, so its counter restarts:
        // the new pair must not equal the (now revoked) old one.
        final dio = _dio(_backend());
        final old = mintRefreshToken('u-100', 1);

        final first = await dio.post<Map<String, Object?>>(
          '/v1/auth/refresh',
          data: {'refreshToken': old},
        );
        final next = first.data!['refreshToken']! as String;
        final second = await dio.post<Map<String, Object?>>(
          '/v1/auth/refresh',
          data: {'refreshToken': next},
        );

        expect(first.statusCode, 200);
        expect(next, isNot(old));
        expect(second.statusCode, 200);
      },
    );

    test('T-0039-AC3 refresh rejects unknown tokens and bad bodies', () async {
      final dio = _dio(_backend());

      final unknown = await dio.post<Map<String, Object?>>(
        '/v1/auth/refresh',
        data: {'refreshToken': 'mc-refresh-u-999-1'},
      );
      final bad = await dio.post<Map<String, Object?>>(
        '/v1/auth/refresh',
        data: {'token': 'x'},
      );

      expect(unknown.statusCode, 401);
      expect(bad.statusCode, 400);
    });

    test(
      'T-0039-AC3 sign-out revokes the refresh token, no bearer needed',
      () async {
        final dio = _dio(_backend());
        final tokens = await _signIn(dio);

        final out = await dio.post<Object?>(
          '/v1/auth/sign-out',
          data: {'refreshToken': tokens['refreshToken']},
        );
        final refresh = await dio.post<Map<String, Object?>>(
          '/v1/auth/refresh',
          data: {'refreshToken': tokens['refreshToken']},
        );
        final bodyless = await dio.post<Object?>('/v1/auth/sign-out');

        expect(out.statusCode, 204);
        expect(refresh.statusCode, 401);
        expect(bodyless.statusCode, 204);
      },
    );
  });

  group('T-0039-AC3 favourites', () {
    Future<Options> signedIn(
      Dio dio, {
      String email = _reader,
      String password = _password,
    }) async => _bearer(
      (await _signIn(dio, email: email, password: password))['accessToken']!
          as String,
    );

    test(
      'T-0039-AC3 the default set seeds the reader, not the collector',
      () async {
        final dio = _dio(_backend());
        final reader = await signedIn(dio);
        final collector = await signedIn(
          dio,
          email: 'collector@mini-client.test',
          password: 'vault-7',
        );

        final seeded = await dio.get<Map<String, Object?>>(
          '/v1/me/favourites/character/100000',
          options: reader,
        );
        final none = await dio.get<Map<String, Object?>>(
          '/v1/me/favourites/character/100000',
          options: collector,
        );

        expect(seeded.statusCode, 200);
        expect(seeded.data, {
          'kind': 'character',
          'id': '100000',
          'favourite': true,
        });
        expect(none.statusCode, 404);
        expect(none.data!['error'], containsPair('code', 'not_favourite'));
      },
    );

    test(
      'T-0039-AC3 a favourites write persists across requests until reset',
      () async {
        final backend = _backend();
        final dio = _dio(backend);
        final options = await signedIn(dio);
        const path = '/v1/me/favourites/comic/4242';

        expect(
          (await dio.get<Object?>(path, options: options)).statusCode,
          404,
        );
        final put = await dio.put<Map<String, Object?>>(path, options: options);
        expect(put.statusCode, 200);
        expect(put.data, {'kind': 'comic', 'id': '4242', 'favourite': true});
        // Idempotent, and visible to later requests and to /v1/me.
        expect(
          (await dio.put<Object?>(path, options: options)).statusCode,
          200,
        );
        expect(
          (await dio.get<Object?>(path, options: options)).statusCode,
          200,
        );
        final me = await dio.get<Map<String, Object?>>(
          '/v1/me',
          options: options,
        );
        expect(me.data!['favouriteCount'], 3);

        // It survives a new sign-in: the store belongs to the backend.
        final again = await signedIn(dio);
        expect((await dio.get<Object?>(path, options: again)).statusCode, 200);

        final del = await dio.delete<Map<String, Object?>>(
          path,
          options: again,
        );
        expect(del.data, {'kind': 'comic', 'id': '4242', 'favourite': false});
        expect((await dio.get<Object?>(path, options: again)).statusCode, 404);

        await dio.put<Object?>(path, options: again);
        backend.reset();
        final afterReset = await signedIn(dio);
        expect(
          (await dio.get<Object?>(path, options: afterReset)).statusCode,
          404,
        );
        expect(
          (await dio.get<Object?>(
            '/v1/me/favourites/character/100000',
            options: afterReset,
          )).statusCode,
          200,
          reason: 'reset returns to the seeded favourites',
        );
      },
    );

    test('T-0039-AC3 an unknown kind is 400 and no bearer is 401', () async {
      final dio = _dio(_backend());
      final options = await signedIn(dio);

      final kind = await dio.put<Map<String, Object?>>(
        '/v1/me/favourites/pony/1',
        options: options,
      );
      final anonymous = await dio.put<Object?>('/v1/me/favourites/comic/1');

      expect(kind.statusCode, 400);
      expect(kind.data!['error'], containsPair('parameter', 'kind'));
      expect(anonymous.statusCode, 401);
    });
  });

  group('T-0039-AC3 determinism', () {
    test(
      'T-0039-AC3 one request sequence gives byte-identical responses',
      () async {
        Future<List<String>> run() async {
          final dio = _plainDio(_backend());
          const access = 'mc-access-u-100-1';
          final calls = <Future<Response<String>> Function()>[
            () => dio.post<String>(
              '/v1/auth/sign-in',
              data: {'email': _reader, 'password': _password},
            ),
            () => dio.get<String>('/v1/me', options: _bearer(access)),
            () => dio.put<String>(
              '/v1/me/favourites/comic/9',
              options: _bearer(access),
            ),
            () => dio.get<String>('/v1/me', options: _bearer(access)),
            () => dio.post<String>(
              '/v1/auth/refresh',
              data: {'refreshToken': 'mc-refresh-u-100-1'},
            ),
          ];
          return [
            for (final call in calls)
              await call().then((r) => '${r.statusCode} ${r.data}'),
          ];
        }

        expect(await run(), await run());
      },
    );
  });

  group('T-0039-AC3 sets and scenarios', () {
    test('T-0039-AC3 the sets are identity.default, empty, server_error', () {
      expect(identityFixtureSets.keys, [
        'identity.default',
        'identity.empty',
        'identity.server_error',
      ]);
      expect(
        identityFixtureSets['identity.default']!(),
        isA<IdentityMockDomain>(),
      );
    });

    test('T-0039-AC3 identity.empty starts with no favourites', () async {
      final dio = _dio(_backend(identityFixtureSets['identity.empty']!()));
      final options = _bearer(
        (await _signIn(dio))['accessToken']! as String,
      );

      final me = await dio.get<Map<String, Object?>>(
        '/v1/me',
        options: options,
      );

      expect(me.data!['favouriteCount'], 0);
    });

    test(
      'T-0039-AC3 identity.server_error answers 500 on every route',
      () async {
        final dio = _dio(
          _backend(identityFixtureSets['identity.server_error']!()),
        );

        for (final route in IdentityMockDomain.routeManifest) {
          final [method, pattern] = route.split(' ');
          final path = pattern
              .replaceFirst(':kind', 'comic')
              .replaceFirst(':id', '1');
          final response = await dio.request<Object?>(
            path,
            options: Options(method: method),
          );
          expect(response.statusCode, 500, reason: route);
        }
      },
    );

    test(
      'T-0039-AC3 the server_error scenario fails every route of the default',
      () async {
        final backend = _backend()..useScenario('identity.server_error');
        final dio = _dio(backend);

        for (final route in IdentityMockDomain.routeManifest) {
          final [method, pattern] = route.split(' ');
          final path = pattern
              .replaceFirst(':kind', 'comic')
              .replaceFirst(':id', '1');
          final response = await dio.request<Object?>(
            path,
            options: Options(method: method),
          );
          expect(response.statusCode, 500, reason: route);
        }
      },
    );

    test(
      'T-0039-AC3 the expired_token scenario issues an expired access token',
      () async {
        final backend = _backend()..useScenario('identity.expired_token');
        final dio = _dio(backend);

        final tokens = await _signIn(dio);
        final rejected = await dio.get<Object?>(
          '/v1/me',
          options: _bearer(tokens['accessToken']! as String),
        );
        final refreshed = await dio.post<Map<String, Object?>>(
          '/v1/auth/refresh',
          data: {'refreshToken': tokens['refreshToken']},
        );
        final accepted = await dio.get<Object?>(
          '/v1/me',
          options: _bearer(refreshed.data!['accessToken']! as String),
        );

        expect(tokens['accessToken'], expiredAccessToken('u-100'));
        expect(rejected.statusCode, 401);
        expect(refreshed.statusCode, 200);
        expect(accepted.statusCode, 200);
      },
    );

    test(
      'T-0039-AC3 the token helpers match what the backend accepts',
      () async {
        final dio = _dio(_backend());

        final me = await dio.get<Object?>(
          '/v1/me',
          options: _bearer(mintAccessToken('u-101', 7)),
        );
        final refresh = await dio.post<Object?>(
          '/v1/auth/refresh',
          data: {'refreshToken': mintRefreshToken('u-101', 7)},
        );

        expect(me.statusCode, 200);
        expect(refresh.statusCode, 200);
      },
    );

    test(
      'T-0047-AC3 userForAuthorization is the check GET /v1/me applies',
      () {
        expect(
          userForAuthorization('Bearer ${mintAccessToken('u-101', 7)}')?.id,
          'u-101',
        );
        for (final header in [
          null,
          '',
          mintAccessToken('u-100', 1),
          'Bearer ${expiredAccessToken('u-100')}',
          'Bearer ${mintRefreshToken('u-100', 1)}',
          'Bearer ${mintAccessToken('u-999', 1)}',
        ]) {
          expect(userForAuthorization(header), isNull, reason: '$header');
        }
      },
    );
  });
}

Dio _plainDio(MockBackend backend) =>
    _dio(backend)..options.responseType = ResponseType.plain;
