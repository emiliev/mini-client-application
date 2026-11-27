// T-0050 Verifier probe: the root Dio as app_core builds it. Not committed.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';

const _config =
    '{"env":"e2e","backend":{"seed":7,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid","build":"1"}';

void main() {
  late Directory storage;
  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('v_root_dio');
  });
  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  test(
    'V-ROOT interceptor order and a pinned race on the real root Dio',
    () async {
      await initializeDIContainer(
        rootInitializers(
          config: () async => _config,
          storageDirectory: storage,
          monitoringSinks: [InMemorySink()],
          mockDomains: const [IdentityMockDomain()],
        ),
      );
      final dio = diContainer<Dio>();
      final order = [
        for (final i in dio.interceptors) i.runtimeType.toString(),
      ];
      // ignore: avoid_print
      print('ORDER $order adapter=${dio.httpClientAdapter.runtimeType}');
      expect(order.last, 'AuthInterceptor');

      final writer = diContainer<SessionWriter>();
      final reader = diContainer<SessionReader>();
      await writer.signIn(
        userId: 'u-100',
        tokens: AuthTokens(
          accessToken: mintAccessToken('u-100', 1),
          refreshToken: mintRefreshToken('u-100', 1),
        ),
      );
      final backend = diContainer<MockBackend>();
      final before = backend.recentTraffic.length;
      final pending = apiCall(
        () => dio.put<Object?>(
          'v1/me/favourites/comic/9',
          options: Options(extra: authPinned(reader.epoch)),
        ),
      );
      writer
          .signIn(
            userId: 'u-101',
            tokens: AuthTokens(
              accessToken: mintAccessToken('u-101', 1),
              refreshToken: mintRefreshToken('u-101', 1),
            ),
          )
          .ignore();
      final r = await pending;
      expect(
        r.fold((_) => 'ok', (f) => f.toString()),
        contains('The session changed'),
      );
      expect(backend.recentTraffic.length, before);
    },
  );
}
