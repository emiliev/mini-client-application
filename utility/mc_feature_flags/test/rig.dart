import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart' show TestFailure;

enum Layout { grid, list, compact }

/// The flags the tests read. Their defaults differ from every value the
/// fixtures serve, so the source of a value can be told from its value.
const FeatureFlag<bool> promoBanner = FeatureFlag<bool>(
  key: 'store.promo_banner',
  defaultValue: true,
  description: 'Shows the promotion banner.',
  codec: BoolFlagCodec(),
);
const FeatureFlag<int> pageSize = FeatureFlag<int>(
  key: 'catalogue.page_size',
  defaultValue: 10,
  description: 'Items per page.',
  codec: IntFlagCodec(),
);
const FeatureFlag<String> accent = FeatureFlag<String>(
  key: 'settings.accent',
  defaultValue: 'blue',
  description: 'The accent colour name.',
  codec: StringFlagCodec(),
);
const FeatureFlag<Layout> searchLayout = FeatureFlag<Layout>(
  key: 'search.layout',
  defaultValue: Layout.compact,
  description: 'The search results layout.',
  codec: EnumFlagCodec<Layout>(Layout.values),
);

/// A flag the backend never sends.
const FeatureFlag<bool> unknownToServer = FeatureFlag<bool>(
  key: 'rig.not_on_the_server',
  defaultValue: false,
  description: 'No fixture serves this key.',
  codec: BoolFlagCodec(),
);

const Experiment storeHomeLayout = Experiment(
  key: 'store_home_layout',
  variants: [
    ExperimentVariant('control', 5000),
    ExperimentVariant('compact', 3000),
    ExperimentVariant('rich', 2000),
  ],
);

/// `GET /v1/flags` with a body the test sets. [flags] and [experiments]
/// are read on every request.
final class StubFlagsDomain implements MockDomain {
  StubFlagsDomain({Map<String, Object?>? flags, List<Object?>? experiments})
    : flags = flags ?? {},
      experiments = experiments ?? [];

  Map<String, Object?> flags;
  List<Object?> experiments;

  /// The bodies served, by the bearer the request carried (null: none).
  final List<String?> authorizations = [];

  @override
  String get name => 'stub_flags';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router.get('/v1/flags', (request, context) {
      authorizations.add(request.headers['authorization']);
      return MockResponse.ok({'flags': flags, 'experiments': experiments});
    });
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// A [FileStore] that remembers its writes, so a test can wait for them
/// (a write is real file I/O, which a zero-length delay does not
/// wait for).
final class TrackingStore extends FileStore {
  TrackingStore(super.directory);

  final List<Future<Object?>> pending = [];

  @override
  Future<Result<void, StorageFailure>> write(String key, Object? value) {
    final done = super.write(key, value);
    pending.add(done);
    return done;
  }

  @override
  Future<Result<void, StorageFailure>> delete(String key) {
    final done = super.delete(key);
    pending.add(done);
    return done;
  }
}

/// One request that [GateAdapter] is holding.
final class Held {
  Held(this.authorization);

  /// The `Authorization` header the request was sent with.
  final String? authorization;
  final Completer<void> _release = Completer<void>();

  bool get released => _release.isCompleted;

  /// Lets the (already computed) response through to the caller.
  void release() => _release.complete();
}

/// Holds the **response** of every `GET /v1/flags` while [holding] is true:
/// the server answers at once (so the body is the one for the user the
/// request was sent as) and the answer reaches the caller only after the test
/// releases it. No timers: the order of arrival is the test's.
final class GateAdapter implements HttpClientAdapter {
  GateAdapter(this.inner);

  final HttpClientAdapter inner;
  bool holding = false;
  final List<Held> held = [];
  final List<(int, Completer<void>)> _waiters = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = await inner.fetch(options, requestStream, cancelFuture);
    if (!holding || !options.path.endsWith('/v1/flags')) {
      return response;
    }
    final entry = Held(options.headers['Authorization'] as String?);
    held.add(entry);
    for (final (count, completer) in List.of(_waiters)) {
      if (held.length >= count && !completer.isCompleted) {
        completer.complete();
      }
    }
    await entry._release.future;
    return response;
  }

  /// Completes when at least [count] requests are being held.
  Future<void> waitForHeld(int count) {
    if (held.length >= count) {
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _waiters.add((count, completer));
    // Only a failing test waits this long: the request never arrived.
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TestFailure(
        'expected $count held request(s), saw ${held.length}',
      ),
    );
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// A real [Session] and [FileStore] on a temp directory, the production Dio
/// stack with the bearer interceptor over a held backend, and the flags.
final class Rig {
  Rig._(
    this.dir,
    this.stub,
    this.backend,
    this.gate,
    this.session,
    this.dio,
    this.sink,
    this.monitoring,
    this.env,
    this._newInstallId,
    this.tracking,
    this.flags,
  );

  static Future<Rig> create({
    String env = 'dev',
    Directory? dir,
    StubFlagsDomain? stub,
    MockDomain? domain,
    bool holding = false,
    bool start = true,
    String Function()? newInstallId,
  }) async {
    final directory = dir ?? Directory.systemTemp.createTempSync('mc_ff_test');
    final stubDomain = stub ?? StubFlagsDomain();
    final backend = MockBackend(
      domains: [const IdentityMockDomain(), domain ?? stubDomain],
    );
    final gate = GateAdapter(backend.adapter)..holding = holding;
    final store = TrackingStore(directory);
    final session = await Session.restore(store);
    final dio = createApiDio(adapter: gate, retryDelay: Duration.zero);
    final api = AuthApi(dio, session, session);
    dio.interceptors.add(AuthInterceptor(dio, session, session, api));
    final sink = InMemorySink();
    final monitoring = Monitoring([sink]);
    var counter = 0;
    final installIds = newInstallId ?? () => 'install-${counter++}';
    final flags = await FeatureFlags.open(
      dio: dio,
      session: session,
      store: store,
      env: env,
      monitoring: monitoring,
      newInstallId: installIds,
    );
    if (start) {
      flags.start();
    }
    return Rig._(
      directory,
      stubDomain,
      backend,
      gate,
      session,
      dio,
      sink,
      monitoring,
      env,
      installIds,
      store,
      flags,
    );
  }

  final Directory dir;
  final StubFlagsDomain stub;
  final MockBackend backend;
  final GateAdapter gate;
  final Session session;
  final Dio dio;
  final InMemorySink sink;
  final Monitoring monitoring;
  final String env;
  final String Function() _newInstallId;
  final TrackingStore tracking;
  FeatureFlags flags;

  FileStore get store => FileStore(dir);

  /// Reports of the flags to monitoring, as messages.
  List<String> get reports => [
    for (final e in sink.entries)
      if (e is LogEntry) e.message,
  ];

  /// What a second launch does: a new session and flags on the same store,
  /// with [domain] (or the same stub) behind the network.
  Future<Rig> relaunch({
    String? env,
    MockDomain? domain,
    bool holding = false,
    bool start = true,
  }) async {
    await flags.dispose();
    await session.dispose();
    return Rig.create(
      env: env ?? this.env,
      dir: dir,
      stub: stub,
      domain: domain,
      holding: holding,
      start: start,
      newInstallId: _newInstallId,
    );
  }

  Future<void> signIn(String userId, [int n = 1]) => session.signIn(
    userId: userId,
    tokens: AuthTokens(
      accessToken: mintAccessToken(userId, n),
      refreshToken: mintRefreshToken(userId, n),
    ),
  );

  Future<void> signOut() => session.signOut();

  /// Lets queued microtasks and stream events run.
  Future<void> settle() async {
    for (var round = 0; round < 3; round++) {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait(List.of(tracking.pending));
    }
  }

  Future<void> dispose({bool deleteDir = true}) async {
    await flags.dispose();
    await session.dispose();
    if (deleteDir && dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}

/// The platform fixtures' domain, for tests that follow the real contract.
const MockDomain fixturesDomain = PlatformMockDomain();
