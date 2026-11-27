import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:test/test.dart';

import 'rig.dart';

ApiFailure _failure(Result<Object?, ApiFailure> r) =>
    r.fold((_) => fail('expected a failure'), (f) => f);

Future<Result<Response<Map<String, Object?>>, ApiFailure>> _get(
  Dio dio,
  String path,
) => apiCall(() => dio.get<Map<String, Object?>>(path));

Future<void> _signInCollector(AuthApi api) async {
  final r = await api.signIn(
    email: 'collector@mini-client.test',
    password: 'vault-7',
  );
  expect(r.getOrNull()?.id, 'u-101');
}

void main() {
  late Rig rig;

  setUp(() async => rig = await Rig.create());
  tearDown(() => rig.dispose());

  group(
    'T-0039-AC2 a refresh outcome belongs to the session it started for',
    () {
      test('T-0039-AC2 a refresh that succeeds after a sign-out leaves the session signed out', () async {
        final gated = GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
        final (dio, api) = rig.dioOver(gated);
        await rig.startExpiredSession();
        final pending = _get(dio, '/v1/me');
        await gated.arrived.future;

        await api.signOut();
        gated.gate.complete();
        final result = await pending;
        await rig.settle();

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.session.isSignedIn, isFalse);
        expect((await Session.restore(rig.store)).isSignedIn, isFalse);
        expect(
          rig.events.where((e) => e.status == AuthStatus.signedOut),
          hasLength(1),
        );
        expect(rig.calls('GET', '/v1/me'), 1, reason: 'no replay');
      });

      for (final holdResponse in [false, true]) {
        test('T-0039-AC2 a refresh of user A that succeeds after user B signed in does not touch B '
            '(${holdResponse ? 'answer' : 'request'} held)', () async {
          final gated = GatedAdapter(
            rig.backend.adapter,
            '/v1/auth/refresh',
            holdResponse: holdResponse,
          );
          final (dio, api) = rig.dioOver(gated);
          await rig.startExpiredSession();
          final pending = _get(dio, '/v1/me');
          await gated.arrived.future;
          await api.signOut();
          await _signInCollector(api);
          final bAccess = rig.session.accessToken;
          final bRefresh = rig.session.refreshToken;

          gated.gate.complete();
          final result = await pending;
          await rig.settle();

          expect(_failure(result), isA<ApiUnauthorized>());
          expect(rig.session.userId, 'u-101');
          expect(rig.session.accessToken, bAccess);
          expect(rig.session.refreshToken, bRefresh);
          expect(
            (await Session.restore(rig.store)).accessToken,
            bAccess,
            reason: 'the saved session is B too',
          );
        });
      }

      test('T-0039-AC2 a refresh of user A that is rejected after user B signed in does not sign B out', () async {
        final gated = GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
        final (dio, api) = rig.dioOver(gated);
        await rig.session.signIn(
          userId: 'u-100',
          tokens: AuthTokens(
            accessToken: expiredAccessToken('u-100'),
            refreshToken: 'garbage',
          ),
        );
        final pending = _get(dio, '/v1/me');
        await gated.arrived.future;
        await rig.session.signOut();
        await _signInCollector(api);

        gated.gate.complete();
        final result = await pending;
        await rig.settle();

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.session.userId, 'u-101');
        expect(
          rig.events.map((e) => e.status),
          [AuthStatus.signedIn, AuthStatus.signedOut, AuthStatus.signedIn],
          reason: 'no spurious sign-out for B',
        );
      });

      test('T-0039-AC2 a 401 of user A answered after A signed out and B signed in is not replayed with B', () async {
        await rig.startExpiredSession();
        final held = _get(rig.dio, '/v1/gated');
        await rig.settle();
        await rig.api.signOut();
        await _signInCollector(rig.api);

        rig.probe.gate.complete();
        final result = await held;

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.calls('GET', '/v1/gated'), 1, reason: 'not replayed');
        expect(rig.calls('POST', '/v1/auth/refresh'), 0);
      });

      test('T-0039-AC2 a PUT favourite of user A is not written into B after A signed out and B signed in', () async {
        final gated = GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
        final (dio, api) = rig.dioOver(gated);
        await rig.startExpiredSession();
        final put = apiCall(
          () => dio.put<Map<String, Object?>>('/v1/me/favourites/comic/77'),
        );
        await gated.arrived.future;
        await api.signOut();
        await _signInCollector(api);

        gated.gate.complete();
        final result = await put;
        await rig.settle();

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.calls('PUT', '/v1/me/favourites/comic/77'), 1);
        final inB = await apiCall(
          () => dio.get<Map<String, Object?>>('/v1/me/favourites/comic/77'),
        );
        expect(_failure(inB), isA<ApiNotFound>());
      });

      test('T-0039-AC2 a request retried after B signed in is failed, not sent with B', () async {
        // Root cause of the old flake (T-0050 D4): the test slept 10 ms in
        // real time hoping to land inside the 50 ms retry delay, so a loaded
        // machine could run the retry first. The switch now happens when the
        // first send arrives at the adapter, before its 503 is answered: it
        // is certain to precede the retry, whatever the clock does.
        var switched = false;
        final arrivals = ArrivalAdapter(rig.backend.adapter, (options) {
          if (!switched && options.path.endsWith('/v1/echo-auth')) {
            switched = true;
            rig.track(rig.session.signOut());
            rig.track(
              rig.session.signIn(
                userId: 'u-101',
                tokens: AuthTokens(
                  accessToken: mintAccessToken('u-101', 1),
                  refreshToken: mintRefreshToken('u-101', 1),
                ),
              ),
            );
          }
        });
        final (dio, api) = rig.dioOver(
          arrivals,
          retryDelay: const Duration(milliseconds: 50),
        );
        await api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        rig.backend.failNext(
          'GET',
          '/v1/echo-auth',
          const FailureKind.http(503),
        );

        final result = await apiCall(
          () => dio.get<Map<String, Object?>>('/v1/echo-auth'),
        );

        expect(switched, isTrue, reason: 'the first send arrived');
        expect(_failure(result), isA<ApiUnauthorized>());
        expect(
          rig.calls('GET', '/v1/echo-auth'),
          1,
          reason: 'the retry never left',
        );
      });

      test('T-0050-AC3 (P-080) one refresh per session: user A is in flight, user B starts its own', () async {
        final gated = GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
        final (dio, _) = rig.dioOver(gated);
        await rig.startExpiredSession();
        final a = _get(dio, '/v1/me');
        await gated.arrived.future;
        await rig.session.signOut();
        await rig.session.signIn(
          userId: 'u-101',
          tokens: AuthTokens(
            accessToken: expiredAccessToken('u-101'),
            refreshToken: mintRefreshToken('u-101', 0),
          ),
        );
        final b = _get(dio, '/v1/me');
        await rig.settle();
        gated.gate.complete();
        final resultA = await a;
        final resultB = await b;
        await rig.settle();

        expect(_failure(resultA), isA<ApiUnauthorized>());
        expect(resultB.getOrNull()?.data?['id'], 'u-101');
        expect(rig.session.userId, 'u-101');
        expect(rig.session.accessToken, startsWith('mc-access-u-101-'));
        expect(
          rig.calls('POST', '/v1/auth/refresh'),
          2,
          reason: 'B did not wait for, or share, the refresh of A',
        );
      });

      test('T-0050-AC3 (P-080) a PUT of user A after a local sign-out during the refresh is not replayed without a token', () async {
        final gated = GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
        final (dio, _) = rig.dioOver(gated);
        await rig.startExpiredSession();
        final put = apiCall(
          () => dio.put<Map<String, Object?>>('/v1/me/favourites/comic/5'),
        );
        await gated.arrived.future;
        await rig.session.signOut();
        gated.gate.complete();
        final result = await put;

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(
          rig.calls('PUT', '/v1/me/favourites/comic/5'),
          1,
          reason: 'the 401 reaches the caller; there is no anonymous replay',
        );
      });

      test('T-0039-AC1 a request retried after a sign-out goes out without the old token', () async {
        final (dio, api) = rig.dioOver(
          rig.backend.adapter,
          retryDelay: const Duration(milliseconds: 50),
        );
        await api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        rig.backend.failNext(
          'GET',
          '/v1/echo-auth',
          const FailureKind.http(503),
        );

        final pending = dio.get<Map<String, Object?>>('/v1/echo-auth');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await rig.session.signOut();
        final response = await pending;

        expect(response.data, {'authorization': null});
      });
    },
  );

  group('T-0039-AC2 bodies that are sent once', () {
    test('T-0039-AC2 a FormData request that gets a 401 is replayed with a copy after the refresh', () async {
      await rig.startExpiredSession();

      final result = await apiCall(
        () => rig.dio.put<Map<String, Object?>>(
          '/v1/me/favourites/comic/1',
          data: FormData.fromMap({'note': 'x'}),
        ),
      );

      expect(result.getOrNull()?.statusCode, 200, reason: '$result');
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
      expect(rig.statuses('/v1/me/favourites/comic/1'), [401, 200]);
    });

    test(
      'T-0039-AC2 a Stream body that gets a 401 is not refreshed or replayed',
      () async {
        await rig.startExpiredSession();

        final result = await apiCall(
          () => rig.dio.put<Map<String, Object?>>(
            '/v1/me/favourites/comic/1',
            data: Stream.value(<int>[1, 2, 3]),
            options: Options(headers: {Headers.contentLengthHeader: 3}),
          ),
        );

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.calls('POST', '/v1/auth/refresh'), 0);
        expect(rig.calls('PUT', '/v1/me/favourites/comic/1'), 1);
        expect(rig.session.isSignedIn, isTrue);
      },
    );
  });

  group('T-0039-AC2 only a definite rejection signs out', () {
    Future<Result<Response<Map<String, Object?>>, ApiFailure>> withFailure(
      HttpClientAdapter Function(HttpClientAdapter inner) wrap,
    ) async {
      await rig.startExpiredSession();
      final (dio, _) = rig.dioOver(wrap(rig.backend.adapter));
      return _get(dio, '/v1/me');
    }

    test('T-0039-AC2 an unexpected error during the refresh (a dropped socket) keeps the session', () async {
      final result = await withFailure(
        (inner) => ThrowingAdapter(
          inner,
          '/v1/auth/refresh',
          (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.unknown,
            error: const SocketException('Connection reset by peer'),
          ),
        ),
      );

      expect(_failure(result), isA<ApiUnexpected>());
      expect(rig.session.isSignedIn, isTrue);
      expect(rig.session.accessToken, expiredAccessToken('u-100'));
    });

    test('T-0039-AC2 a cancelled refresh keeps the session', () async {
      final result = await withFailure(
        (inner) => ThrowingAdapter(
          inner,
          '/v1/auth/refresh',
          (o) => DioException.requestCancelled(requestOptions: o, reason: 'x'),
        ),
      );

      expect(_failure(result), isA<ApiUnexpected>());
      expect(rig.session.isSignedIn, isTrue);
    });

    test('T-0039-AC2 a 429 on the refresh keeps the session', () async {
      await rig.startExpiredSession();
      rig.backend.failNext(
        'POST',
        '/v1/auth/refresh',
        const FailureKind.http(429),
      );

      final result = await _get(rig.dio, '/v1/me');

      expect(
        _failure(result),
        isA<ApiClientError>().having((f) => f.status, 'status', 429),
      );
      expect(rig.session.isSignedIn, isTrue);
    });

    test(
      'T-0039-AC2 a 403 on the refresh is a rejection and signs out',
      () async {
        await rig.startExpiredSession();
        rig.backend.failNext(
          'POST',
          '/v1/auth/refresh',
          const FailureKind.http(403),
        );

        final result = await _get(rig.dio, '/v1/me');

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.session.isSignedIn, isFalse);
      },
    );
  });

  group('T-0039-AC2 what is not refreshed', () {
    test('T-0039-AC2 a 403 on a request is not refreshed', () async {
      await rig.api.signIn(
        email: 'reader@mini-client.test',
        password: 'marvelous',
      );
      rig.backend.failNext('GET', '/v1/me', const FailureKind.http(403));

      final result = await _get(rig.dio, '/v1/me');

      expect(
        _failure(result),
        isA<ApiClientError>().having((f) => f.status, 'status', 403),
      );
      expect(rig.calls('POST', '/v1/auth/refresh'), 0);
      expect(rig.calls('GET', '/v1/me'), 1);
    });

    test('T-0039-AC2 a replay that gets a 401 again ends after 2 calls and 1 refresh', () async {
      await rig.startExpiredSession();

      final result = await _get(rig.dio, '/v1/always-401-capped');

      // Without the replay flag this loops until the route's cap turns it
      // into a 500, and the counts below fail instead of the test timing out.
      expect(_failure(result), isA<ApiUnauthorized>());
      expect(rig.calls('POST', '/v1/auth/refresh'), lessThanOrEqualTo(1));
      expect(rig.calls('GET', '/v1/always-401-capped'), 2);
    });
  });
}
