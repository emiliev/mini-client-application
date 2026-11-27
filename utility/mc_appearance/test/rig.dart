import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart' show TestFailure;

const String reader = 'u-100';
const String collector = 'u-101';
const String preferencesPath = '/v1/me/preferences';

/// One request [GateAdapter] is holding.
final class Held {
  Held(this.options);

  final RequestOptions options;
  final Completer<void> _release = Completer<void>();

  /// The bearer the request left with.
  String? get authorization => options.headers['Authorization'] as String?;

  void release() => _release.complete();
}

/// Holds the next request to a method and path, either **before the server
/// sees it** (it has left the device, the server has not answered) or
/// **after the server answered** (the account is already written, the
/// answer has not arrived). No timers: the test decides the order.
final class GateAdapter implements HttpClientAdapter {
  GateAdapter(this.inner);

  final HttpClientAdapter inner;
  final List<({String method, bool beforeServer, Completer<Held> arrived})>
  _next = [];

  /// The methods of every request to the preferences that left the device,
  /// in order (the backend's own traffic also has the test's direct reads).
  final List<String> sent = [];

  /// Holds the next [method] to the preferences; completes when it arrives.
  Future<Held> holdNext(String method, {bool beforeServer = false}) {
    final arrived = Completer<Held>();
    _next.add((method: method, beforeServer: beforeServer, arrived: arrived));
    return arrived.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TestFailure('no $method $preferencesPath arrived'),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path == preferencesPath) {
      sent.add(options.method);
    }
    final index = _next.indexWhere(
      (n) => n.method == options.method && options.uri.path == preferencesPath,
    );
    if (index < 0) {
      return inner.fetch(options, requestStream, cancelFuture);
    }
    final gate = _next.removeAt(index);
    final held = Held(options);
    if (gate.beforeServer) {
      gate.arrived.complete(held);
      await held._release.future;
      return inner.fetch(options, requestStream, cancelFuture);
    }
    final response = await inner.fetch(options, requestStream, cancelFuture);
    gate.arrived.complete(held);
    await held._release.future;
    return response;
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// A real [Session] and [FileStore] on a temp directory, the production Dio
/// stack (retry, bearer, pin) over the identity fixtures behind a
/// [GateAdapter], and the [Appearance].
final class Rig {
  Rig._(
    this.dir,
    this.backend,
    this.gate,
    this.session,
    this.store,
    this.sink,
    this.appearance,
  );

  static Future<Rig> create({
    Directory? dir,
    MockBackend? backend,
    String? signedInAs,
    bool start = true,
    bool followAccount = true,
  }) async {
    final directory = dir ?? Directory.systemTemp.createTempSync('mc_app_');
    final server =
        backend ?? MockBackend(domains: [const IdentityMockDomain()]);
    final gate = GateAdapter(server.adapter);
    final store = FileStore(directory);
    final session = await Session.restore(store);
    final dio = createApiDio(adapter: gate, retryDelay: Duration.zero);
    final api = AuthApi(dio, session, session);
    dio.interceptors.add(AuthInterceptor(dio, session, session, api));
    final sink = InMemorySink();
    final rig = Rig._(
      directory,
      server,
      gate,
      session,
      store,
      sink,
      Appearance.open(
        dio: dio,
        session: session,
        store: store,
        monitoring: Monitoring([sink]),
        followAccount: followAccount,
      ),
    );
    if (signedInAs != null) {
      await rig.signIn(signedInAs);
    }
    if (start) {
      rig.appearance.start();
    }
    return rig;
  }

  final Directory dir;
  final MockBackend backend;
  final GateAdapter gate;
  final Session session;
  final FileStore store;
  final InMemorySink sink;
  final Appearance appearance;
  int _tokens = 0;

  AppearancePreferences get shown => appearance.snapshot.preferences;
  AppearanceSyncStatus get status => appearance.snapshot.status;

  /// What a second launch does: a new session and appearance on the same
  /// directory and backend.
  Future<Rig> relaunch() async {
    await quiesce();
    return Rig.create(dir: dir, backend: backend);
  }

  /// Signs [userId] in, as the sign-in flow ends (a new epoch each time).
  Future<void> signIn(String userId) {
    _tokens++;
    return session.signIn(
      userId: userId,
      tokens: AuthTokens(
        accessToken: mintAccessToken(userId, _tokens),
        refreshToken: mintRefreshToken(userId, _tokens),
      ),
    );
  }

  Future<void> signOut() => session.signOut();

  /// Lets stream events, answers and the sync run end.
  Future<void> settle() async {
    for (var round = 0; round < 3; round++) {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await appearance.settled();
    }
  }

  /// The app's requests to the preferences that left the device, as `GET`
  /// or `PATCH` (a retried `GET` counts each try).
  List<String> get preferencesTraffic => List.of(gate.sent);

  int count(String method) =>
      preferencesTraffic.where((m) => m == method).length;

  /// The account's copy of [userId], read straight from the backend.
  Future<Map<String, Object?>> account(String userId) async {
    final response = await backend.createDio().get<Map<String, Object?>>(
      preferencesPath,
      options: Options(
        headers: {'Authorization': 'Bearer ${mintAccessToken(userId, 1)}'},
      ),
    );
    return response.data!;
  }

  /// Another device of [userId] changes the account's copy.
  Future<void> otherDeviceWrites(
    String userId,
    Map<String, Object> change,
  ) async {
    final version = (await account(userId))['version']! as int;
    final response = await backend.createDio().patch<Object?>(
      preferencesPath,
      data: {'ifVersion': version, ...change},
      options: Options(
        headers: {'Authorization': 'Bearer ${mintAccessToken(userId, 1)}'},
      ),
    );
    if (response.statusCode != 200) {
      throw TestFailure('the other device could not write: $response');
    }
  }

  /// The device's saved copy, as JSON.
  Object? get saved => store.readSync(appearanceStoreKey).getOrNull();

  /// Warnings the appearance reported.
  List<String> get warnings => [
    for (final e in sink.entries)
      if (e is LogEntry) e.message,
  ];

  /// Stops the appearance and waits for the session's saves. The
  /// appearance's own saves are synchronous, so none is ever running.
  Future<void> quiesce() async {
    await appearance.settled();
    await appearance.dispose();
    await session.dispose();
  }

  Future<void> dispose() async {
    await quiesce();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}
