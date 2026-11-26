// T-0039 Verifier probes. Not part of the branch; removed after the run.
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
    r.fold((_) => fail('expected a failure'), (f) => f);

Future<Result<Response<Map<String, Object?>>, ApiFailure>> _get(
  Dio dio,
  String path,
) => apiCall(() => dio.get<Map<String, Object?>>(path));

/// Holds every request to [heldPath] until [gate] completes.
final class _GatedAdapter implements HttpClientAdapter {
  _GatedAdapter(this.inner, this.heldPath);
  final HttpClientAdapter inner;
  final String heldPath;
  Completer<void> gate = Completer<void>();
  final Completer<void> arrived = Completer<void>();
  final List<String?> seenAuth = [];
  bool holdResponse = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seenAuth.add(options.headers['Authorization'] as String?);
    if (holdResponse && options.path.endsWith(heldPath)) {
      final response = await inner.fetch(options, requestStream, cancelFuture);
      if (!arrived.isCompleted) {
        arrived.complete();
      }
      await gate.future;
      return response;
    }
    if (options.path.endsWith(heldPath)) {
      if (!arrived.isCompleted) {
        arrived.complete();
      }
      await gate.future;
    }
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Rig rig;
  setUp(() async => rig = await Rig.create());
  tearDown(() => rig.dispose());

  test('V-P1 10 concurrent 401s share one refresh', () async {
    await rig.startExpiredSession();
    final results = await Future.wait([
      for (var i = 0; i < 10; i++) _get(rig.dio, '/v1/me'),
    ]);
    expect(results.map((r) => r.getOrNull()?.statusCode), List.filled(10, 200));
    expect(rig.calls('POST', '/v1/auth/refresh'), 1);
    expect(rig.statuses('/v1/me'), [
      ...List.filled(10, 401),
      ...List.filled(10, 200),
    ]);
  });

  test(
    'V-P1b 10 concurrent 401s under realistic latency share one refresh',
    () async {
      final slow = await Rig.create(
        latency: const LatencyProfile.realistic(
          base: Duration(milliseconds: 10),
          jitter: Duration(milliseconds: 40),
        ),
      );
      addTearDown(slow.dispose);
      await slow.startExpiredSession();
      final results = await Future.wait([
        for (var i = 0; i < 10; i++) _get(slow.dio, '/v1/me'),
      ]);
      expect(
        results.map((r) => r.getOrNull()?.statusCode),
        List.filled(10, 200),
      );
      expect(slow.calls('POST', '/v1/auth/refresh'), 1);
    },
  );

  test(
    'V-P2 a 401 after the refresh does not loop (2 calls, 1 refresh)',
    () async {
      await rig.startExpiredSession();
      final r = await _get(rig.dio, '/v1/always-401');
      expect(_failure(r), isA<ApiUnauthorized>());
      expect(rig.calls('GET', '/v1/always-401'), 2);
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
    },
  );

  test('V-P3 the refresh call itself getting a 401 does not recurse', () async {
    await rig.startExpiredSession();
    rig.backend.failNext(
      'POST',
      '/v1/auth/refresh',
      const FailureKind.unauthorized(),
    );
    final r = await _get(rig.dio, '/v1/me');
    await rig.settle();
    expect(_failure(r), isA<ApiUnauthorized>());
    expect(rig.calls('POST', '/v1/auth/refresh'), 1);
    expect(rig.calls('GET', '/v1/me'), 1);
    expect(rig.session.isSignedIn, isFalse);
    expect(rig.events.last, const SessionChanged(AuthStatus.signedOut));
  });

  test('V-P5 no token + 401: no refresh attempt', () async {
    final r = await _get(rig.dio, '/v1/me');
    expect(_failure(r), isA<ApiUnauthorized>());
    expect(rig.calls('POST', '/v1/auth/refresh'), 0);
  });

  test('V-P6a refresh 403 (4xx) signs out', () async {
    await rig.startExpiredSession();
    rig.backend.failNext(
      'POST',
      '/v1/auth/refresh',
      const FailureKind.http(403),
    );
    final r = await _get(rig.dio, '/v1/me');
    expect(_failure(r), isA<ApiUnauthorized>());
    expect(rig.session.isSignedIn, isFalse);
  });

  test('V-P6b refresh timeout keeps the session and reports timeout', () async {
    await rig.startExpiredSession();
    rig.backend.failNext(
      'POST',
      '/v1/auth/refresh',
      const FailureKind.timeout(),
    );
    final r = await _get(rig.dio, '/v1/me');
    expect(_failure(r), isA<ApiTimeout>());
    expect(rig.session.isSignedIn, isTrue);
    await rig.settle();
    expect(rig.events, const [SessionChanged(AuthStatus.signedIn)]);
  });

  test('V-P6c refresh 503 keeps the session (POST is not retried)', () async {
    await rig.startExpiredSession();
    rig.backend.failNext(
      'POST',
      '/v1/auth/refresh',
      const FailureKind.http(503),
    );
    final r = await _get(rig.dio, '/v1/me');
    expect(_failure(r), isA<ApiServer>());
    expect(rig.session.isSignedIn, isTrue);
    expect(rig.calls('POST', '/v1/auth/refresh'), 1);
  });

  test('V-P6d 3 concurrent 401s + offline refresh: one refresh, all offline, session kept', () async {
    await rig.startExpiredSession();
    rig.backend.failNext(
      'POST',
      '/v1/auth/refresh',
      const FailureKind.offline(),
    );
    final results = await Future.wait([
      for (var i = 0; i < 3; i++) _get(rig.dio, '/v1/me'),
    ]);
    expect(results.map(_failure), everyElement(isA<ApiOffline>()));
    expect(rig.calls('POST', '/v1/auth/refresh'), 1);
    expect(rig.session.isSignedIn, isTrue);
  });

  test('V-P7 a 403 on a request is not refreshed', () async {
    await rig.api.signIn(
      email: 'reader@mini-client.test',
      password: 'marvelous',
    );
    rig.backend.failNext('GET', '/v1/me', const FailureKind.http(403));
    final r = await _get(rig.dio, '/v1/me');
    expect(r.getOrNull(), isNull);
    expect(rig.calls('POST', '/v1/auth/refresh'), 0);
    expect(rig.calls('GET', '/v1/me'), 1);
  });

  test(
    'V-P8 a FormData request that gets a 401 is replayed after the refresh',
    () async {
      await rig.startExpiredSession();
      final r = await apiCall(
        () => rig.dio.put<Map<String, Object?>>(
          '/v1/me/favourites/comic/1',
          data: FormData.fromMap({'note': 'x'}),
        ),
      );
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
      expect(r.getOrNull()?.statusCode, 200, reason: '$r');
    },
  );

  group('gated', () {
    late _GatedAdapter gated;
    late Dio dio;
    late AuthApi api;

    setUp(() {
      gated = _GatedAdapter(rig.backend.adapter, '/v1/auth/refresh');
      dio = createApiDio(adapter: gated, retryDelay: Duration.zero);
      api = AuthApi(dio, rig.session, rig.session);
      dio.interceptors.add(AuthInterceptor(dio, rig.session, rig.session, api));
    });

    test('V-P4a refresh in flight, user signs out, refresh succeeds: stays signed out', () async {
      await rig.startExpiredSession();
      final pending = _get(dio, '/v1/me');
      await gated.arrived.future;
      await api.signOut();
      gated.gate.complete();
      final r = await pending;
      await _settle();
      expect(_failure(r), isA<ApiUnauthorized>());
      expect(rig.session.isSignedIn, isFalse);
      expect((await Session.restore(rig.store)).isSignedIn, isFalse);
      expect(
        rig.events.where((e) => e.status == AuthStatus.signedOut),
        hasLength(1),
      );
      // The replay went out without the old bearer.
      expect(gated.seenAuth.last, isNull);
    });

    test('V-P4b refresh in flight, sign-out, sign-in as another user, old refresh succeeds', () async {
      await rig.startExpiredSession(); // u-100
      final pending = _get(dio, '/v1/me');
      await gated.arrived.future;
      await api.signOut();
      final b = await api.signIn(
        email: 'collector@mini-client.test',
        password: 'vault-7',
      );
      final bUser = b.getOrNull()?.id;
      final bAccess = rig.session.accessToken;
      gated.gate.complete();
      await pending;
      await _settle();
      // A's refresh result must not be written into B's session.
      expect(rig.session.userId, bUser);
      expect(
        rig.session.accessToken,
        bAccess,
        reason:
            'session userId=${rig.session.userId} token=${rig.session.accessToken}',
      );
    });

    test('V-P4e refresh answered by the server, response delayed; meanwhile sign-out + sign-in as B', () async {
      gated.holdResponse = true;
      await rig.startExpiredSession(); // u-100
      final pending = _get(dio, '/v1/me');
      await gated.arrived.future;
      await api.signOut();
      final b = await api.signIn(
        email: 'collector@mini-client.test',
        password: 'vault-7',
      );
      final bAccess = rig.session.accessToken;
      expect(b.getOrNull()?.id, 'u-101');
      gated.gate.complete();
      await pending;
      await _settle();
      expect(rig.session.userId, 'u-101');
      expect(
        rig.session.accessToken,
        bAccess,
        reason:
            'session userId=${rig.session.userId} token=${rig.session.accessToken}',
      );
    });

    test('V-P4c refresh in flight, sign-out, sign-in as B, old refresh rejected: B stays signed in', () async {
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
      final b = await api.signIn(
        email: 'collector@mini-client.test',
        password: 'vault-7',
      );
      expect(b.getOrNull(), isNotNull);
      gated.gate.complete();
      await pending;
      await _settle();
      expect(
        rig.session.isSignedIn,
        isTrue,
        reason: 'a rejected refresh of the old user signed the new user out',
      );
    });

    test('V-P4d sign-out while the first refresh is in flight; concurrent waiters fail unauthorized', () async {
      await rig.startExpiredSession();
      final a = _get(dio, '/v1/me');
      final b = _get(dio, '/v1/me');
      await gated.arrived.future;
      await rig.session.signOut();
      gated.gate.complete();
      final results = await Future.wait([a, b]);
      expect(results.map(_failure), everyElement(isA<ApiUnauthorized>()));
      expect(rig.calls('POST', '/v1/auth/refresh'), 1);
    });
  });

  test('V-AC1 session change during a retry backoff: the retry uses the current session', () async {
    final d = createApiDio(
      adapter: rig.backend.adapter,
      retryDelay: const Duration(milliseconds: 50),
    );
    final api = AuthApi(d, rig.session, rig.session);
    d.interceptors.add(AuthInterceptor(d, rig.session, rig.session, api));
    await api.signIn(email: 'reader@mini-client.test', password: 'marvelous');
    rig.backend.failNext('GET', '/v1/echo-auth', const FailureKind.http(503));
    final pending = d.get<Map<String, Object?>>('/v1/echo-auth');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await rig.session.signOut();
    final r = await pending;
    expect(r.data, {'authorization': null});
  });

  test(
    'V-AC1 sign-in as B during a retry backoff: the retry carries B',
    () async {
      final d = createApiDio(
        adapter: rig.backend.adapter,
        retryDelay: const Duration(milliseconds: 50),
      );
      final api = AuthApi(d, rig.session, rig.session);
      d.interceptors.add(AuthInterceptor(d, rig.session, rig.session, api));
      await api.signIn(email: 'reader@mini-client.test', password: 'marvelous');
      rig.backend.failNext('GET', '/v1/echo-auth', const FailureKind.http(503));
      final pending = d.get<Map<String, Object?>>('/v1/echo-auth');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await api.signIn(
        email: 'collector@mini-client.test',
        password: 'vault-7',
      );
      final r = await pending;
      expect(r.data, {'authorization': 'Bearer ${rig.session.accessToken}'});
    },
  );

  test(
    'V-AC1 sign-out while a request is in flight: a 401 is not refreshed',
    () async {
      await rig.api.signIn(
        email: 'reader@mini-client.test',
        password: 'marvelous',
      );
      final held = _get(rig.dio, '/v1/gated');
      await rig.settle();
      await rig.api.signOut();
      rig.probe.gate.complete();
      final r = await held;
      // Sent with a valid token, so the server answers 200 even after the
      // client signed out; then nothing else happens.
      expect(r.getOrNull()?.statusCode, 200);
      expect(rig.calls('POST', '/v1/auth/refresh'), 0);
    },
  );
}
