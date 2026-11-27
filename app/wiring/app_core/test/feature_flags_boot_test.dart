import 'dart:async';
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

const _config =
    '{"env":"e2e","backend":{"seed":7,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid","build":"1"}';

const FeatureFlag<String> _layout = FeatureFlag<String>(
  key: 'search.layout',
  defaultValue: 'compact',
  description: 'The search results layout.',
  codec: StringFlagCodec(),
);

/// `GET /v1/flags` that answers only when the test lets it: the response is
/// held on a completer, not on a timer.
final class _HeldFlagsDomain implements MockDomain {
  final Completer<void> release = Completer<void>();
  int calls = 0;

  @override
  String get name => 'held_flags';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router.get('/v1/flags', (request, context) async {
      calls++;
      await release.future;
      return MockResponse.ok({
        'flags': {'search.layout': 'grid'},
        'experiments': <Object?>[],
      });
    });
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [GoRoute(path: '/', builder: (_, _) => const Text('home'))],
);

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('app_core_flags_boot');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  testWidgets('T-0052-AC3 boot reaches home while the flags response is held '
      'on a completer, with the default value; the value arrives later', (
    tester,
  ) async {
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    final held = _HeldFlagsDomain();
    final sink = InMemorySink();
    final initializers = rootInitializers(
      config: () async => _config,
      storageDirectory: storage,
      monitoringSinks: [sink],
      mockDomains: [held],
    );
    expect(
      initializers.whereType<FeatureFlagsDIInitializer>(),
      hasLength(1),
      reason: 'the flags are in the root list',
    );

    await tester.pumpWidget(
      McApp(
        boot: () => initializeDIContainer(initializers),
        router: _router,
        links: links,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('home'), findsOneWidget, reason: 'boot did not wait');
    expect(find.byType(BootPage), findsNothing);
    // The request leaves through Dio's interceptors a few timer turns later.
    await tester.pump(const Duration(milliseconds: 10));
    expect(held.calls, 1, reason: 'the fetch was started at boot');
    expect(held.release.isCompleted, isFalse);
    final flags = diContainer<FeatureFlagsReader>();
    expect(flags.value(_layout), 'compact', reason: 'the default meanwhile');

    held.release.complete();
    await tester.pump(const Duration(milliseconds: 10));
    expect(flags.value(_layout), 'grid');
  });

  testWidgets('T-0052-AC3 boot reaches home when the flags backend fails, '
      'and the flags are the defaults', (tester) async {
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    final initializers = rootInitializers(
      config: () async => _config.replaceFirst(
        '"scenario":"happy"',
        '"scenario":"platform.server_error"',
      ),
      storageDirectory: storage,
      monitoringSinks: [InMemorySink()],
      mockDomains: const [PlatformMockDomain()],
    );
    await tester.pumpWidget(
      McApp(
        boot: () => initializeDIContainer(initializers),
        router: _router,
        links: links,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
    expect(diContainer<FeatureFlagsReader>().value(_layout), 'compact');
    // The retry interceptor waits 200 ms between attempts; let them end.
    await tester.pump(const Duration(seconds: 2));
  });

  test('T-0052-AC3 the root list puts the flags right after api auth, as '
      'plan 01 §3.4 orders it', () {
    final list = rootInitializers(
      config: () async => _config,
      storageDirectory: Directory.systemTemp,
    );
    final flags = list.indexWhere((i) => i is FeatureFlagsDIInitializer);
    expect(flags, greaterThan(0));
    expect(list[flags - 1].runtimeType.toString(), 'ApiAuthDIInitializer');
  });

  test('T-0052-AC3 the app serves the platform domain', () {
    expect(appMockDomains.whereType<PlatformMockDomain>(), hasLength(1));
  });
}
