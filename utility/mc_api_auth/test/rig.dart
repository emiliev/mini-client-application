import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

/// Routes only the tests use, next to the identity domain.
final class ProbeDomain implements MockDomain {
  ProbeDomain();

  /// Completes the request held by `GET /v1/gated`.
  final Completer<void> gate = Completer<void>();
  int _cappedCalls = 0;

  @override
  String get name => 'probe';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router
      // The Authorization header the server saw, or null.
      ..get(
        '/v1/echo-auth',
        (request, context) => MockResponse.ok({
          'authorization': request.headers['authorization'],
        }),
      )
      // Always 401, even with a good token.
      ..get(
        '/v1/always-401',
        (request, context) =>
            MockResponse.error(401, 'unauthenticated', 'Never signed in'),
      )
      // 401 for its first 5 calls, then 500: a refresh/replay loop ends
      // with an assertion instead of a timeout.
      ..get('/v1/always-401-capped', (request, context) {
        _cappedCalls++;
        return _cappedCalls <= 5
            ? MockResponse.error(401, 'unauthenticated', 'Never signed in')
            : MockResponse.error(500, 'capped', 'The loop ran too long');
      })
      // Looks at the token when the request arrives, then waits for [gate]:
      // a request that was sent with an old token but is answered late.
      ..get('/v1/gated', (request, context) async {
        final auth = userForAuthorizationHeader(
          request.headers['authorization'],
        );
        await gate.future;
        return auth
            ? MockResponse.ok({'ok': true})
            : MockResponse.error(401, 'unauthenticated', 'Expired');
      });
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// True for an access token the identity fixtures accept.
bool userForAuthorizationHeader(String? header) =>
    header != null && RegExp(r'^Bearer mc-access-u-\d+-\d+$').hasMatch(header);

/// A real session on a temp directory, a real [Dio] with the production
/// interceptors, and the identity fixtures on the mocked backend.
final class Rig {
  Rig._(
    this.dir,
    this.backend,
    this.probe,
    this.bus,
    this.session,
    this.dio,
    this.api,
    this.events,
  );

  static Future<Rig> create({
    LatencyProfile latency = LatencyProfile.none,
    MockDomain identity = const IdentityMockDomain(),
  }) async {
    final dir = Directory.systemTemp.createTempSync('mc_api_auth_test');
    final probe = ProbeDomain();
    final backend = MockBackend(domains: [identity, probe], latency: latency);
    final bus = EventBus();
    final events = <SessionChanged>[];
    bus.on<SessionChanged>().listen(events.add);
    final session = await Session.restore(FileStore(dir), bus: bus);
    final dio = createApiDio(
      adapter: backend.adapter,
      retryDelay: Duration.zero,
    );
    final api = AuthApi(dio, session, session);
    dio.interceptors.add(AuthInterceptor(dio, session, session, api));
    return Rig._(dir, backend, probe, bus, session, dio, api, events);
  }

  final Directory dir;
  final MockBackend backend;
  final ProbeDomain probe;
  final EventBus bus;
  final Session session;
  final Dio dio;
  final AuthApi api;

  /// Every [SessionChanged] seen so far (delivery is a microtask later, so
  /// `await settle()` before reading).
  final List<SessionChanged> events;

  FileStore get store => FileStore(dir);

  /// Signs the reader in directly, with an access token that is already
  /// expired and a good refresh token, number 0 so the next one the backend
  /// mints (number 1) differs from it (what a restored old session looks
  /// like).
  Future<void> startExpiredSession() => session.signIn(
    userId: 'u-100',
    tokens: AuthTokens(
      accessToken: expiredAccessToken('u-100'),
      refreshToken: mintRefreshToken('u-100', 0),
    ),
  );

  /// How many requests reached `path` with [method], whatever the answer.
  int calls(String method, String path) => backend.recentTraffic
      .where((t) => t.method == method && t.path == path)
      .length;

  /// The statuses `path` answered, in order.
  List<int?> statuses(String path) => [
    for (final t in backend.recentTraffic)
      if (t.path == path) t.status,
  ];

  /// A second [Dio] with the production interceptors and the auth interceptor
  /// over [adapter], on this rig's session.
  (Dio, AuthApi) dioOver(
    HttpClientAdapter adapter, {
    Duration retryDelay = Duration.zero,
  }) {
    final d = createApiDio(adapter: adapter, retryDelay: retryDelay);
    final a = AuthApi(d, session, session);
    d.interceptors.add(AuthInterceptor(d, session, session, a));
    return (d, a);
  }

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    await bus.dispose();
    await session.dispose();
    dir.deleteSync(recursive: true);
  }
}

/// Holds requests to [heldPath] on a gate: before the server sees them
/// ([holdResponse] false) or after it answered ([holdResponse] true).
final class GatedAdapter implements HttpClientAdapter {
  GatedAdapter(this.inner, this.heldPath, {this.holdResponse = false});

  final HttpClientAdapter inner;
  final String heldPath;
  final bool holdResponse;
  final Completer<void> gate = Completer<void>();
  final Completer<void> arrived = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!options.path.endsWith(heldPath)) {
      return inner.fetch(options, requestStream, cancelFuture);
    }
    if (holdResponse) {
      final response = await inner.fetch(options, requestStream, cancelFuture);
      _arrive();
      await gate.future;
      return response;
    }
    _arrive();
    await gate.future;
    return inner.fetch(options, requestStream, cancelFuture);
  }

  void _arrive() {
    if (!arrived.isCompleted) {
      arrived.complete();
    }
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// Throws [error] for every request to [path].
final class ThrowingAdapter implements HttpClientAdapter {
  ThrowingAdapter(this.inner, this.path, this.error);

  final HttpClientAdapter inner;
  final String path;
  final DioException Function(RequestOptions) error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.path.endsWith(path)) {
      throw error(options);
    }
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
