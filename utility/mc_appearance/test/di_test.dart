import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mc_app_di_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('T-0063-AC7 the initializer registers one appearance under its three '
      'types, with the saved values, and starts it', () async {
    final store = FileStore(dir)
      ..writeSync(appearanceStoreKey, {
        'themeMode': 'dark',
        'density': 'compact',
        'reduceMotion': true,
      });
    final backend = MockBackend(domains: [const IdentityMockDomain()]);
    final session = Session.empty(store);
    final dio = createApiDio(adapter: backend.adapter);
    dio.interceptors.add(
      AuthInterceptor(dio, session, session, AuthApi(dio, session, session)),
    );
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<Dio>(dio)
      ..registerSingleton<SessionReader>(session)
      ..registerSingleton<FileStore>(store)
      ..registerSingleton<Monitoring>(Monitoring([InMemorySink()]));

    await const AppearanceDIInitializer().init(getIt);

    final appearance = getIt<Appearance>();
    expect(getIt<AppearanceReader>(), same(appearance));
    expect(getIt<AppearanceSettings>(), same(appearance));
    expect(
      appearance.snapshot.preferences,
      const AppearancePreferences(
        themeMode: AppearanceThemeMode.dark,
        density: AppearanceDensity.compact,
        reduceMotion: true,
      ),
    );
    expect(appearance.snapshot.status, AppearanceSyncStatus.local);

    // Started: it follows the session.
    final seen = <AppearanceSyncStatus>[];
    final sub = appearance.changes.listen((s) => seen.add(s.status));
    await session.signIn(
      userId: 'u-100',
      tokens: AuthTokens(
        accessToken: mintAccessToken('u-100', 1),
        refreshToken: mintRefreshToken('u-100', 1),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await appearance.settled();
    expect(seen, contains(AppearanceSyncStatus.pending));
    expect(appearance.snapshot.status, AppearanceSyncStatus.synced);
    await sub.cancel();

    // The reset disposes it: later session changes are ignored.
    await getIt.reset();
    await session.signOut();
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(appearance.snapshot.status, AppearanceSyncStatus.synced);
    await session.dispose();
  });
}
