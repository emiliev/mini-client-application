// T-0050 Verifier probes. Not part of the branch: copied into
// utility/mc_api_auth/test/ for the run, then removed.
import 'dart:async';
import 'dart:typed_data';

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
    r.fold((_) => fail('expected a failure, got $r'), (f) => f);

AuthTokens _tokensOf(String userId) => AuthTokens(
  accessToken: mintAccessToken(userId, 1),
  refreshToken: mintRefreshToken(userId, 1),
);

/// Every request that reached the adapter: method, path, Authorization.
final class Recording implements HttpClientAdapter {
  Recording(this.inner, {this.onArrive});
  final HttpClientAdapter inner;
  final FutureOr<void> Function(RequestOptions)? onArrive;
  final seen = <(String, String, Object?)>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add((options.method, options.path, options.headers['Authorization']));
    await onArrive?.call(options);
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// Runs [action] when a request to [path] enters this interceptor.
final class Hook extends Interceptor {
  Hook(this.path, this.action);
  final String path;
  final void Function() action;
  bool fired = false;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!fired && options.path.endsWith(path)) {
      fired = true;
      action();
    }
    handler.next(options);
  }
}

void main() {
  late Rig rig;

  setUp(() async {
    rig = await Rig.create();
  });
  tearDown(() => rig.dispose());

  group('V-AC1 kit', () {
    test('V1 pin made stale in the chain (after retry, before auth)', () async {
      await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
      final rec = Recording(rig.backend.adapter);
      final (dio, _) = rig.dioOver(rec);
      // Insert just in front of the auth interceptor (index = last).
      dio.interceptors.insert(
        dio.interceptors.length - 1,
        Hook('/comic/9', () {
          rig.session
              .signIn(userId: 'u-101', tokens: _tokensOf('u-101'))
              .ignore();
        }),
      );
      final r = await apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );
      expect(_failure(r), isA<ApiUnauthorized>());
      expect(rec.seen, isEmpty);
    });

    test('V2 pin made stale during a refresh (B signs in): no replay, '
        'never B bearer', () async {
      final gated = GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
      final rec = Recording(gated);
      final (dio, _) = rig.dioOver(rec);
      await rig.startExpiredSession();
      final epoch = rig.session.epoch;
      final put = apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(epoch)),
        ),
      );
      await gated.arrived.future;
      await rig.session.signIn(userId: 'u-101', tokens: _tokensOf('u-101'));
      gated.gate.complete();
      final r = await put;
      expect(_failure(r), isA<ApiUnauthorized>());
      final puts = rec.seen.where((e) => e.$1 == 'PUT').toList();
      expect(puts, hasLength(1));
      expect(puts.single.$3, isNot(contains('u-101')));
    });

    test('V3 pin made stale after the refresh, before the replay is sent '
        '(sign-out): the replay is rejected by the pin', () async {
      // Sign out the moment the refresh answer has been applied, i.e. when
      // the replay enters the chain: without the pin, the replay would go
      // out without a bearer (ours && token == null path).
      late Recording rec;
      var puts = 0;
      rec = Recording(rig.backend.adapter, onArrive: (o) {});
      final (dio, _) = rig.dioOver(rec);
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.method == 'PUT' && ++puts == 2) {
              rig.session.signOut().ignore();
            }
            h.next(o);
          },
        ),
      );
      await rig.startExpiredSession();
      final r = await apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );
      expect(puts, 2, reason: 'the replay entered the chain');
      expect(_failure(r), isA<ApiUnauthorized>());
      final sent = rec.seen.where((e) => e.$1 == 'PUT').toList();
      expect(sent, hasLength(1), reason: 'only the first 401 went out: $sent');
    });

    test('V4 a retry (5xx) keeps the pin: sign-out during the retry delay, '
        'no anonymous retry', () async {
      await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
      rig.backend.addFailure(
        const FailureRule(
          'PUT',
          '/v1/me/favourites/comic/:id',
          FailureKind.http(503),
          FailureTrigger.once,
        ),
      );
      final rec = Recording(
        rig.backend.adapter,
        onArrive: (o) {
          if (rig.session.isSignedIn) {
            // Answer 503 first, then sign out before the retry is sent.
            scheduleMicrotask(() => rig.session.signOut().ignore());
          }
        },
      );
      final (dio, _) = rig.dioOver(rec);
      final r = await apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(rig.session.epoch)),
        ),
      );
      expect(
        rec.seen.where((e) => e.$1 == 'PUT'),
        hasLength(1),
        reason: '${rec.seen}',
      );
      expect(r.getOrNull(), isNull);
    });

    test('V5 copyWith keeps the pin; fetch of a copy after a switch is '
        'rejected', () async {
      await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
      final rec = Recording(rig.backend.adapter);
      final (dio, _) = rig.dioOver(rec);
      final base = Options(
        method: 'PUT',
        extra: authPinned(rig.session.epoch),
      ).compose(dio.options, '/v1/me/favourites/comic/9');
      final copy = base.copyWith(path: '/v1/me/favourites/comic/9');
      expect(copy.extra[mcSessionEpoch], rig.session.epoch);
      final copy2 = base.copyWith(extra: {...base.extra, 'x': 1});
      expect(copy2.extra[mcSessionEpoch], rig.session.epoch);
      await rig.session.signIn(userId: 'u-101', tokens: _tokensOf('u-101'));
      final r = await apiCall(() => dio.fetch<Object?>(copy));
      expect(_failure(r), isA<ApiUnauthorized>());
      expect(rec.seen, isEmpty);
    });

    test('V6 a refresh does not change the epoch', () async {
      await rig.startExpiredSession();
      final before = rig.session.epoch;
      final r = await apiCall(() => rig.dio.get<Object?>('/v1/me'));
      expect(r.getOrNull(), isNotNull, reason: "$r");
      expect(rig.session.accessToken, isNot(expiredAccessToken('u-100')));
      expect(rig.session.epoch, before);
    });

    test('V7 the rejected pinned request does not hit the retry or the '
        'refresh (error interceptors skipped)', () async {
      await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
      final rec = Recording(rig.backend.adapter);
      final (dio, _) = rig.dioOver(rec);
      final epoch = rig.session.epoch;
      final f = apiCall(
        () => dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(epoch)),
        ),
      );
      rig.session.signOut().ignore();
      expect(_failure(await f), isA<ApiUnauthorized>());
      await rig.settle();
      expect(rec.seen, isEmpty, reason: 'no refresh, no retry');
    });

    test('V8 a same-user re-sign-in also invalidates the pin '
        '(documented conservative)', () async {
      await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
      final epoch = rig.session.epoch;
      final f = apiCall(
        () => rig.dio.put<Object?>(
          '/v1/me/favourites/comic/9',
          options: Options(extra: authPinned(epoch)),
        ),
      );
      rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100')).ignore();
      expect(_failure(await f), isA<ApiUnauthorized>());
    });

    test('V9 a non-int pin is ignored (unpinned)', () async {
      await rig.session.signIn(userId: 'u-100', tokens: _tokensOf('u-100'));
      final r = await rig.dio.get<Map<String, Object?>>(
        '/v1/echo-auth',
        options: Options(extra: {mcSessionEpoch: '1'}),
      );
      expect(r.data?['authorization'], 'Bearer mc-access-u-100-1');
    });
  });
}
