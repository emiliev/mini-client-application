import 'dart:async';
import 'dart:io';

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
