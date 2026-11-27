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

AuthTokens _tokensOf(String userId) => AuthTokens(
  accessToken: mintAccessToken(userId, 1),
  refreshToken: mintRefreshToken(userId, 1),
);

/// The in-memory switch is synchronous; the save is kept and awaited by the
/// rig's dispose, before it deletes the storage folder.
void _signInNow(Rig rig, String userId) =>
    rig.track(rig.session.signIn(userId: userId, tokens: _tokensOf(userId)));

void _signOutNow(Rig rig) => rig.track(rig.session.signOut());

void main() {
  late Rig rig;

  setUp(() async {
    rig = await Rig.create();
    await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
  });
  tearDown(() => rig.dispose());

  // The T-0048 Verifier's timing (D1): the caller checked the epoch, started
  // the write, and the user switched in the same turn, before Dio ran the
  // first request interceptor (which it does in a later event-loop turn).
  Future<Result<Response<Map<String, Object?>>, ApiFailure>> pinnedWrite(
    int epoch,
  ) => apiCall(
    () => rig.dio.put<Map<String, Object?>>(
      '/v1/me/favourites/comic/9',
      options: Options(extra: authPinned(epoch)),
    ),
  );

  group('T-0050-AC1 a pinned request never leaves for another session', () {
    test(
      'T-0050-AC1 a user switch right after the call: no request, unauthorized',
      () async {
        final pending = pinnedWrite(rig.session.epoch);
        _signInNow(rig, 'u-101');
        final result = await pending;

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(
          rig.backend.recentTraffic,
          isEmpty,
          reason: 'nothing reached the backend, under no bearer',
        );
      },
    );

    test('T-0050-AC1 a sign-out right after the call: no request', () async {
      final pending = pinnedWrite(rig.session.epoch);
      _signOutNow(rig);
      final result = await pending;

      expect(_failure(result), isA<ApiUnauthorized>());
      expect(rig.backend.recentTraffic, isEmpty);
    });

    test('T-0050-AC1 the failure says the session changed', () async {
      final pending = pinnedWrite(rig.session.epoch);
      _signInNow(rig, 'u-101');

      expect(
        _failure(await pending).toString(),
        contains('The session changed'),
      );
    });

    test(
      'T-0050-AC1 a pinned request of the current session gets the bearer',
      () async {
        final response = await rig.dio.get<Map<String, Object?>>(
          '/v1/echo-auth',
          options: Options(extra: authPinned(rig.session.epoch)),
        );

        expect(response.data, {'authorization': 'Bearer mc-access-u-100-1'});
      },
    );

    test('T-0050-AC1 the pin of a signed-out session sends no bearer while still signed out', () async {
      await rig.session.signOut();

      final response = await rig.dio.get<Map<String, Object?>>(
        '/v1/echo-auth',
        options: Options(extra: authPinned(rig.session.epoch)),
      );

      expect(response.data, {'authorization': null});
    });

    test('T-0050-AC1 a request pinned to a signed-out epoch is rejected after a sign-in', () async {
      await rig.session.signOut();
      final pending = apiCall(
        () => rig.dio.get<Map<String, Object?>>(
          '/v1/echo-auth',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );
      _signInNow(rig, 'u-101');

      expect(_failure(await pending), isA<ApiUnauthorized>());
      expect(rig.backend.recentTraffic, isEmpty);
    });

    test('T-0050-AC1 a request that skips auth ignores the pin', () async {
      final epoch = rig.session.epoch;
      _signInNow(rig, 'u-101');

      final response = await rig.dio.get<Map<String, Object?>>(
        '/v1/echo-auth',
        options: Options(extra: {...authPinned(epoch), skipAuthKey: true}),
      );

      expect(response.data, {'authorization': null});
    });

    test('T-0050-AC1 a pinned request that gets a 401 is refreshed and replayed once for its own session', () async {
      await rig.startExpiredSession();

      final result = await apiCall(
        () => rig.dio.put<Map<String, Object?>>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );

      expect(result.getOrNull()?.statusCode, 200, reason: '$result');
      expect(rig.statuses('/v1/me/favourites/comic/9'), [401, 200]);
    });

    test('T-0050-AC1 unpinned requests are unchanged: the switch gives the new bearer', () async {
      final pending = rig.dio.get<Map<String, Object?>>('/v1/echo-auth');
      _signInNow(rig, 'u-101');
      final response = await pending;

      expect(
        response.data,
        {'authorization': 'Bearer mc-access-u-101-1'},
        reason: 'documented: only a pinned request is held to its session',
      );
    });

    test('T-0050-AC1 a replay after the refresh keeps the pin: a sign-out '
        'between the refresh and the replay sends nothing more', () async {
      // The user signs out the moment the replay enters the chain: without
      // the pin on replays it would go out with no bearer.
      var puts = 0;
      final arrivals = ArrivalAdapter(rig.backend.adapter, (_) {});
      final (dio, _) = rig.dioOver(arrivals);
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'PUT' && ++puts == 2) {
              _signOutNow(rig);
            }
            handler.next(options);
          },
        ),
      );
      await rig.startExpiredSession();

      final result = await apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );

      expect(puts, 2, reason: 'the replay entered the chain');
      expect(_failure(result), isA<ApiUnauthorized>());
      expect(
        arrivals.seen.where((e) => e.$1 == 'PUT'),
        hasLength(1),
        reason: 'only the first, expired send reached the backend',
      );
    });

    test('T-0050-AC1 a retry after a 5xx keeps the pin: a sign-out during the '
        'retry sends no anonymous retry', () async {
      rig.backend.failNext(
        'PUT',
        '/v1/me/favourites/comic/9',
        const FailureKind.http(503),
      );
      // The sign-out happens when the first send arrives, so it is certain
      // to precede the retry (no wall-clock wait).
      final arrivals = ArrivalAdapter(rig.backend.adapter, (_) {
        if (rig.session.isSignedIn) {
          _signOutNow(rig);
        }
      });
      final (dio, _) = rig.dioOver(arrivals);

      final result = await apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );

      expect(
        arrivals.seen.where((e) => e.$1 == 'PUT'),
        hasLength(1),
        reason: 'the retry never left: ${arrivals.seen}',
      );
      expect(_failure(result), isA<ApiUnauthorized>());
    });

    test(
      'T-0050-AC1 authPinned carries the epoch under the documented key',
      () {
        expect(authPinned(7), {mcSessionEpoch: 7});
        expect(mcSessionEpoch, 'mc_api_auth.pinned_epoch');
      },
    );
  });
}
