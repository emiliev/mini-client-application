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
  Rig rig,
  String path, {
  Options? options,
}) => apiCall(() => rig.dio.get<Map<String, Object?>>(path, options: options));

void main() {
  late Rig rig;

  setUp(() async => rig = await Rig.create());
  tearDown(() => rig.dispose());

  group('T-0039-AC1 the bearer header', () {
    test(
      'T-0039-AC1 a signed-in session sends Authorization: Bearer <token>',
      () async {
        await rig.session.signIn(
          userId: 'u-100',
          tokens: AuthTokens(
            accessToken: mintAccessToken('u-100', 5),
            refreshToken: mintRefreshToken('u-100', 5),
          ),
        );

        final response = await rig.dio.get<Map<String, Object?>>(
          '/v1/echo-auth',
        );

        expect(response.data, {'authorization': 'Bearer mc-access-u-100-5'});
      },
    );

    test(
      'T-0039-AC1 signed out, a request carries no Authorization header',
      () async {
        final response = await rig.dio.get<Map<String, Object?>>(
          '/v1/echo-auth',
        );

        expect(response.data, {'authorization': null});
      },
    );

    test(
      'T-0039-AC1 the header follows the session: sign-in, then sign-out',
      () async {
        final signedIn = await rig.api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        final during = await rig.dio.get<Map<String, Object?>>('/v1/echo-auth');
        await rig.api.signOut();
        final after = await rig.dio.get<Map<String, Object?>>('/v1/echo-auth');

        expect(signedIn.getOrNull()?.id, 'u-100');
        expect(during.data, {'authorization': 'Bearer mc-access-u-100-1'});
        expect(after.data, {'authorization': null});
      },
    );

    test('T-0039-AC1 a real authenticated route accepts the token', () async {
      await rig.api.signIn(
        email: 'reader@mini-client.test',
        password: 'marvelous',
      );

      final me = await _get(rig, '/v1/me');

      expect(me.getOrNull()!.data!['id'], 'u-100');
    });

    test(
      'T-0039-AC1 a header the caller set is left alone and never refreshed',
      () async {
        await rig.startExpiredSession();

        final echoed = await rig.dio.get<Map<String, Object?>>(
          '/v1/echo-auth',
          options: Options(headers: {'Authorization': 'Bearer custom'}),
        );
        final rejected = await _get(
          rig,
          '/v1/me',
          options: Options(headers: {'Authorization': 'Bearer custom'}),
        );

        expect(echoed.data, {'authorization': 'Bearer custom'});
        expect(_failure(rejected), isA<ApiUnauthorized>());
        expect(rig.calls('POST', '/v1/auth/refresh'), 0);
        expect(rig.session.isSignedIn, isTrue);
      },
    );

    test(
      'T-0039-AC1 a 5xx retried by the retry interceptor keeps the bearer',
      () async {
        await rig.api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        rig.backend.failNext('GET', '/v1/me', const FailureKind.http(503));

        final me = await _get(rig, '/v1/me');

        expect(me.getOrNull()!.statusCode, 200);
        expect(rig.statuses('/v1/me'), [503, 200]);
        expect(rig.calls('POST', '/v1/auth/refresh'), 0);
      },
    );

    test('T-0039-AC1 a 401 while signed out is not refreshed', () async {
      final result = await _get(rig, '/v1/me');

      expect(_failure(result), isA<ApiUnauthorized>());
      expect(rig.calls('POST', '/v1/auth/refresh'), 0);
      expect(rig.calls('GET', '/v1/me'), 1);
    });
  });

  group('T-0039-AC2 one refresh then one retry', () {
    test('T-0039-AC2 an expired token is refreshed once and the request replayed once', () async {
      await rig.startExpiredSession();

      final me = await _get(rig, '/v1/me');
      await rig.settle();

      expect(me.getOrNull()!.data!['id'], 'u-100');
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
      expect(rig.statuses('/v1/me'), [401, 200]);
      expect(rig.session.accessToken, 'mc-access-u-100-1');
      expect(rig.session.refreshToken, 'mc-refresh-u-100-1');
      expect(
        rig.events,
        const [SessionChanged(AuthStatus.signedIn)],
        reason: 'a refresh is not a session change (only the seeding sign-in)',
      );
    });

    test(
      'T-0039-AC2 the new tokens are saved: a new session sees them',
      () async {
        await rig.startExpiredSession();
        await _get(rig, '/v1/me');

        final restored = await Session.restore(rig.store);

        expect(restored.accessToken, rig.session.accessToken);
        expect(restored.refreshToken, rig.session.refreshToken);
        expect(restored.accessToken, isNot(expiredAccessToken('u-100')));
      },
    );

    test(
      'T-0039-AC2 3 concurrent requests that all get a 401 share one refresh',
      () async {
        await rig.startExpiredSession();

        final results = await Future.wait([
          _get(rig, '/v1/me'),
          _get(rig, '/v1/me'),
          _get(rig, '/v1/me'),
        ]);

        expect(results.map((r) => r.getOrNull()?.statusCode), [200, 200, 200]);
        expect(rig.calls('POST', '/v1/auth/refresh'), 1);
        // Three real 401s first, then three replays.
        expect(rig.statuses('/v1/me'), [401, 401, 401, 200, 200, 200]);
        expect(rig.session.isSignedIn, isTrue);
      },
    );

    test(
      'T-0039-AC2 the same under latency, with a request that starts later',
      () async {
        final slow = await Rig.create(
          latency: const LatencyProfile.realistic(
            base: Duration(milliseconds: 20),
            jitter: Duration(milliseconds: 30),
          ),
        );
        addTearDown(slow.dispose);
        await slow.startExpiredSession();

        final first = [_get(slow, '/v1/me'), _get(slow, '/v1/me')];
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final late = _get(slow, '/v1/me');
        final results = await Future.wait([...first, late]);

        expect(results.map((r) => r.getOrNull()?.statusCode), [200, 200, 200]);
        expect(slow.calls('POST', '/v1/auth/refresh'), 1);
        expect(slow.session.isSignedIn, isTrue);
      },
    );

    test('T-0039-AC2 a 401 that arrives after the refresh is replayed without a second refresh', () async {
      await rig.startExpiredSession();
      // Sent with the expired token; the server looks at the token now and
      // answers only when the gate opens.
      final held = _get(rig, '/v1/gated');
      await rig.settle();

      final me = await _get(rig, '/v1/me');
      expect(me.getOrNull()!.statusCode, 200);
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);

      rig.probe.gate.complete();
      final result = await held;

      expect(result.getOrNull()!.statusCode, 200);
      expect(
        rig.calls('POST', '/v1/auth/refresh'),
        1,
        reason: 'the late 401 saw a newer token and only replayed',
      );
      expect(rig.statuses('/v1/gated'), [401, 200]);
    });

    test(
      'T-0039-AC2 a replay that gets a 401 again is not refreshed again',
      () async {
        await rig.startExpiredSession();

        final result = await _get(rig, '/v1/always-401');

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.calls('POST', '/v1/auth/refresh'), 1);
        expect(rig.calls('GET', '/v1/always-401'), 2);
        expect(rig.session.isSignedIn, isTrue);
      },
    );

    test(
      'T-0039-AC2 a second expiry refreshes again with the rotated token',
      () async {
        await rig.startExpiredSession();
        await _get(rig, '/v1/me');
        // The server forgets the access token (expired again), the refresh
        // token is the one the first refresh handed out.
        final rotated = rig.session.refreshToken!;
        await rig.session.updateTokens(
          AuthTokens(
            accessToken: expiredAccessToken('u-100'),
            refreshToken: rotated,
          ),
        );

        final me = await _get(rig, '/v1/me');

        expect(me.getOrNull()!.statusCode, 200);
        expect(rig.calls('POST', '/v1/auth/refresh'), 2);
        expect(rig.session.refreshToken, isNot(rotated));
      },
    );

    test(
      'T-0039-AC2 the expired_token scenario signs in expired and recovers',
      () async {
        final scenario = await Rig.create();
        addTearDown(scenario.dispose);
        scenario.backend.useScenario('identity.expired_token');
        await scenario.api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        expect(scenario.session.accessToken, expiredAccessToken('u-100'));

        final me = await _get(scenario, '/v1/me');

        expect(me.getOrNull()!.statusCode, 200);
        expect(scenario.calls('POST', '/v1/auth/refresh'), 1);
      },
    );
  });

  group('T-0039-AC2 a failed refresh signs out', () {
    Future<void> startWithBadRefreshToken() => rig.session.signIn(
      userId: 'u-100',
      tokens: AuthTokens(
        accessToken: expiredAccessToken('u-100'),
        refreshToken: 'garbage',
      ),
    );

    test('T-0039-AC2 a refresh that fails clears the session, publishes signedOut and fails with unauthorized', () async {
      await startWithBadRefreshToken();

      final result = await _get(rig, '/v1/me');
      await rig.settle();

      expect(_failure(result), isA<ApiUnauthorized>());
      expect(rig.session.status, AuthStatus.signedOut);
      expect(rig.session.accessToken, isNull);
      expect(rig.events, const [
        SessionChanged(AuthStatus.signedIn),
        SessionChanged(AuthStatus.signedOut),
      ]);
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
      expect(rig.calls('GET', '/v1/me'), 1, reason: 'no replay');
      expect((await Session.restore(rig.store)).isSignedIn, isFalse);
    });

    test('T-0039-AC2 3 concurrent 401s with a failing refresh: one refresh, one sign-out, three failures', () async {
      await startWithBadRefreshToken();

      final results = await Future.wait([
        _get(rig, '/v1/me'),
        _get(rig, '/v1/me'),
        _get(rig, '/v1/me'),
      ]);
      await rig.settle();

      expect(results.map(_failure), everyElement(isA<ApiUnauthorized>()));
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
      expect(
        rig.events.where((e) => e.status == AuthStatus.signedOut),
        hasLength(1),
      );
    });

    test('T-0039-AC2 a used (rotated) refresh token also signs out', () async {
      await rig.startExpiredSession();
      await rig.dio.post<Object?>(
        '/v1/auth/refresh',
        data: {'refreshToken': rig.session.refreshToken},
        options: Options(extra: {skipAuthKey: true}),
      );

      final result = await _get(rig, '/v1/me');

      expect(_failure(result), isA<ApiUnauthorized>());
      expect(rig.session.isSignedIn, isFalse);
    });

    test(
      'T-0039-AC2 a refresh the server rejects as malformed signs out',
      () async {
        await rig.startExpiredSession();
        rig.backend.failNext(
          'POST',
          '/v1/auth/refresh',
          const FailureKind.malformed(),
        );

        final result = await _get(rig, '/v1/me');

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.session.isSignedIn, isFalse);
      },
    );

    test('T-0039-AC2 a refresh that cannot be tried (offline) keeps the session and reports why', () async {
      await rig.startExpiredSession();
      rig.backend.failNext(
        'POST',
        '/v1/auth/refresh',
        const FailureKind.offline(),
      );

      final failed = await _get(rig, '/v1/me');
      expect(_failure(failed), isA<ApiOffline>());
      expect(rig.session.isSignedIn, isTrue);
      expect(rig.events, const [SessionChanged(AuthStatus.signedIn)]);

      // The next request starts a fresh refresh, which now works.
      final again = await _get(rig, '/v1/me');
      expect(again.getOrNull()!.statusCode, 200);
      expect(rig.calls('POST', '/v1/auth/refresh'), 2);
    });

    test(
      'T-0039-AC2 a refresh that hits a server error keeps the session',
      () async {
        await rig.startExpiredSession();
        rig.backend.failNext(
          'POST',
          '/v1/auth/refresh',
          const FailureKind.http(500),
        );

        final failed = await _get(rig, '/v1/me');

        expect(_failure(failed), isA<ApiServer>());
        expect(rig.session.isSignedIn, isTrue);
      },
    );

    test(
      'T-0039-AC2 a late 401 after a forced sign-out is not refreshed',
      () async {
        await rig.startExpiredSession();
        final held = _get(rig, '/v1/gated');
        await rig.settle();
        // Make the refresh fail: the first request signs the session out.
        await rig.session.updateTokens(
          AuthTokens(
            accessToken: expiredAccessToken('u-100'),
            refreshToken: 'garbage',
          ),
        );
        await _get(rig, '/v1/me');
        expect(rig.session.isSignedIn, isFalse);

        rig.probe.gate.complete();
        final result = await held;

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.calls('POST', '/v1/auth/refresh'), 1);
      },
    );
  });
}
