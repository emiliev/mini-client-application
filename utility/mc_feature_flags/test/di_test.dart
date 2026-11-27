import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

import 'rig.dart';

String _config(String env) =>
    '{"env":"$env","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid","build":"1"}';

/// What the root list has registered before `FeatureFlagsDIInitializer`.
Future<(GetIt, Directory, GateAdapter, Session)> _root({
  String env = 'dev',
  bool holding = false,
  Directory? dir,
}) async {
  final directory = dir ?? Directory.systemTemp.createTempSync('mc_ff_di');
  final getIt = GetIt.asNewInstance();
  final store = FileStore(directory);
  final session = await Session.restore(store);
  final gate = GateAdapter(
    MockBackend(
      domains: [const IdentityMockDomain(), const PlatformMockDomain()],
    ).adapter,
  )..holding = holding;
  final dio = createApiDio(adapter: gate, retryDelay: Duration.zero);
  dio.interceptors.add(
    AuthInterceptor(dio, session, session, AuthApi(dio, session, session)),
  );
  getIt
    ..registerSingleton<AppConfig>(AppConfig.parse(_config(env)))
    ..registerSingleton<Monitoring>(Monitoring([InMemorySink()]))
    ..registerSingleton<FileStore>(store)
    ..registerSingleton<SessionReader>(session)
    ..registerSingleton<Dio>(dio);
  return (getIt, directory, gate, session);
}

/// Runs the initializer; a hang (it waited for the network) fails the test
/// instead of timing it out.
Future<void> _init(GetIt getIt) =>
    Future.value(const FeatureFlagsDIInitializer().init(getIt)).timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw TestFailure('the initializer waited for the network'),
    );

void main() {
  final dirs = <Directory>[];
  tearDown(() {
    for (final dir in dirs) {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
    dirs.clear();
  });

  test('T-0052-AC3 the initializer registers the flags and its two ports '
      'without waiting for the network (the response is held)', () async {
    final (getIt, dir, gate, session) = await _root(holding: true);
    dirs.add(dir);
    // Completes although the response is held: boot does not wait for it.
    await _init(getIt);

    expect(getIt.isRegistered<FeatureFlags>(), isTrue);
    final flags = getIt<FeatureFlags>();
    expect(getIt<FeatureFlagsReader>(), same(flags));
    expect(getIt<FeatureFlagOverrides>(), same(flags));
    // Registered with the default; the fetch has started but is not done.
    expect(flags.value(searchLayout), Layout.compact);
    await gate.waitForHeld(1);
    expect(flags.value(searchLayout), Layout.compact);
    gate.held.single.release();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(flags.value(searchLayout), Layout.grid);
    await getIt.reset();
    await session.dispose();
  });

  test('T-0052-AC3 the initializer takes the environment from AppConfig: '
      'release-like envs reject overrides', () async {
    final (getIt, dir, _, session) = await _root(env: 'release');
    dirs.add(dir);
    await _init(getIt);
    expect(getIt<FeatureFlagOverrides>().isEnabled, isFalse);
    await getIt.reset();
    await session.dispose();

    final (dev, dir2, _, session2) = await _root();
    dirs.add(dir2);
    await _init(dev);
    expect(dev<FeatureFlagOverrides>().isEnabled, isTrue);
    await dev.reset();
    await session2.dispose();
  });

  test('T-0052-AC3 resetting the container disposes the flags: a response '
      'that arrives afterwards changes nothing', () async {
    final (getIt, dir, gate, session) = await _root(holding: true);
    dirs.add(dir);
    await _init(getIt);
    final flags = getIt<FeatureFlags>();
    await gate.waitForHeld(1);
    await getIt.reset();
    gate.held.single.release();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(flags.value(searchLayout), Layout.compact);
    expect(Directory(dir.path).listSync(), isEmpty, reason: 'nothing saved');
    await session.dispose();
  });

  test('T-0052-AC3 a first launch reads no file: nothing saved means no '
      'read (boot stays free of I/O)', () async {
    final (getIt, dir, _, session) = await _root();
    dirs.add(dir);
    expect(Directory(dir.path).listSync(), isEmpty);
    final store = getIt<FileStore>();
    expect(store.existsSync(flagsCacheKey), isFalse);
    expect(store.existsSync(flagsOverridesKey), isFalse);
    expect(store.existsSync(flagsInstallIdKey), isFalse);
    await _init(getIt);
    await getIt.reset();
    await session.dispose();
  });
}
