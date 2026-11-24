import 'dart:async';
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';

const _config =
    '{"env":"e2e","backend":{"seed":7,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid","build":"1"}';

/// A wiring initializer that throws on its first [failures] runs.
McDIInitializer _flaky(int failures, void Function() onRun) {
  var left = failures;
  return McDIInitializer((GetIt getIt, String? environment) {
    onRun();
    if (left-- > 0) {
      throw StateError('wiring exploded');
    }
  });
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('home')),
  ],
);

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('app_core_boot_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  List<McDIInitializer> roots(List<McDIInitializer> wirings) =>
      rootInitializers(
        config: () async => _config,
        storageDirectory: storage,
        monitoringSinks: [InMemorySink()],
        wirings: wirings,
      );

  testWidgets(
    'T-0021-AC1 a failing root initializer shows the error and Retry '
    'succeeds on the second attempt',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      var runs = 0;
      final initializers = roots([_flaky(1, () => runs++)]);
      await tester.pumpWidget(
        McApp(
          boot: () => initializeDIContainer(initializers),
          router: _router,
          links: links,
        ),
      );
      await tester.pump();

      expect(find.byKey(BootPage.failedKey), findsOneWidget);
      expect(find.text('Could not start'), findsOneWidget);
      expect(find.textContaining('wiring exploded'), findsOneWidget);
      expect(find.text('home'), findsNothing);
      expect(diContainer.isRegistered<AppConfig>(), isFalse);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(runs, 2);
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(BootPage), findsNothing);
      expect(diContainer.isRegistered<AppConfig>(), isTrue);
    },
  );

  testWidgets(
    'T-0021-AC2 boot taking longer than 10 s shows the timeout state, and '
    'Retry abandons the attempt and starts a fresh one',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final attempts = <Completer<void>>[];
      var abandons = 0;
      await tester.pumpWidget(
        McApp(
          boot: () {
            attempts.add(Completer<void>());
            return attempts.last.future;
          },
          abandonBoot: () => abandons++,
          router: _router,
          links: links,
        ),
      );

      await tester.pump(const Duration(seconds: 9));
      expect(find.byKey(BootPage.loadingKey), findsOneWidget);
      expect(find.byKey(BootPage.timedOutKey), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(BootPage.timedOutKey), findsOneWidget);
      expect(find.text('Taking too long'), findsOneWidget);
      expect(find.text('Start-up did not finish within 10 s.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(abandons, 1);
      expect(attempts, hasLength(2));
      expect(find.byKey(BootPage.loadingKey), findsOneWidget);

      // The abandoned attempt's late result is ignored; the fresh one counts.
      attempts.first.completeError(StateError('stale'));
      await tester.pump();
      expect(find.byKey(BootPage.loadingKey), findsOneWidget);
      attempts.last.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets(
    'T-0021-AC2 Retry escapes a never-completing root initializer: the hung '
    'mc_di run is abandoned and a fresh one boots (P-028)',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      var runs = 0;
      final hang = Completer<void>(); // never completed
      final initializers = roots([
        McDIInitializer((GetIt getIt, String? environment) {
          if (runs++ == 0) {
            return hang.future;
          }
        }),
      ]);
      await tester.pumpWidget(
        McApp(
          boot: () => initializeDIContainer(initializers),
          router: _router,
          links: links,
        ),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(find.byKey(BootPage.timedOutKey), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(runs, 2);
      expect(find.text('home'), findsOneWidget);
      expect(diContainer.isRegistered<AppConfig>(), isTrue);
    },
  );

  testWidgets(
    'T-0021-AC2 a boot that succeeds after the timeout showed goes to ready',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final held = Completer<void>();
      await tester.pumpWidget(
        McApp(boot: () => held.future, router: _router, links: links),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(find.byKey(BootPage.timedOutKey), findsOneWidget);

      held.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets(
    'T-0021-AC1 a boot that fails after the timeout showed shows the error '
    'and records it to monitoring',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final held = Completer<void>();
      final sink = InMemorySink();
      await tester.pumpWidget(
        McApp(
          boot: () => held.future,
          router: _router,
          links: links,
          bootMonitoring: Monitoring([sink]),
        ),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(find.byKey(BootPage.timedOutKey), findsOneWidget);

      held.completeError(StateError('late failure'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(BootPage.failedKey), findsOneWidget);
      expect(find.textContaining('late failure'), findsOneWidget);
      final errors = sink.entries.whereType<ErrorEntry>().toList();
      expect(errors, hasLength(1));
      expect(errors.single.error.toString(), contains('late failure'));
    },
  );

  test('T-0021-AC1 BootBloc (a McBloc) discards a failed run, so Retry runs '
      'the task again, and the failure is recorded to monitoring', () async {
    var runs = 0;
    var fail = true;
    final sink = InMemorySink();
    final bloc = BootBloc(
      monitoring: Monitoring([sink]),
      task: () async {
        runs++;
        if (fail) {
          fail = false;
          throw StateError('first');
        }
      },
    )..add(const BootStarted());
    await pumpEventQueue();
    expect(bloc.state, isA<BootFailed>());
    expect((bloc.state as BootFailed).attempt, 1);
    final errors = sink.entries.whereType<ErrorEntry>().toList();
    expect(errors, hasLength(1));
    expect(errors.single.error.toString(), contains('first'));

    bloc.add(const BootRetried());
    await pumpEventQueue();
    expect(bloc.state, isA<BootReady>());
    expect(runs, 2);
    expect(bloc.taskRuns, 2);
    // Terminal: retry and start do nothing.
    bloc
      ..add(const BootRetried())
      ..add(const BootStarted());
    await pumpEventQueue();
    expect(runs, 2);
    await bloc.close();
  });

  test('the root list registers every root type once, with the backend '
      'behind Dio', () async {
    final sink = InMemorySink();
    await initializeDIContainer(
      rootInitializers(
        config: () async => _config,
        storageDirectory: storage,
        monitoringSinks: [sink],
      ),
    );
    expect(diContainer<AppConfig>().env, 'e2e');
    expect(diContainer<AppConfig>().backend.seed, 7);
    expect(diContainer<FileStore>().directory.path, storage.path);
    expect(diContainer<MockBackend>().seed, 7);
    expect(diContainer<MockBackend>().latency, same(LatencyProfile.none));
    final dio = diContainer<Dio>();
    expect(dio.options.baseUrl, 'https://mock.mini-client.invalid');
    final adapter = dio.httpClientAdapter as MockBackendHttpAdapter;
    expect(adapter.target, same(diContainer<MockBackend>().adapter));
    expect(diContainer.isRegistered<EventBus>(), isTrue);

    // A request goes through mc_api_client's Dio to the mocked backend,
    // which has no domains, so it answers 404 and records the traffic.
    await expectLater(
      dio.get<Object?>('/v1/nothing'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
    expect(diContainer<MockBackend>().recentTraffic, hasLength(1));
    expect(sink.entries, isNotEmpty, reason: 'the API client logs requests');
  });

  test('T-0021-AC1 an unknown backend.scenario fails boot with a clear '
      'error', () async {
    await expectLater(
      initializeDIContainer(
        rootInitializers(
          config: () async =>
              _config.replaceFirst('"scenario":"happy"', '"scenario":"hapy"'),
          storageDirectory: storage,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('Unknown backend.scenario "hapy"'), contains('happy')),
        ),
      ),
    );
    expect(diContainer.isRegistered<AppConfig>(), isFalse);
  });

  test('a configured latency becomes a constant backend latency', () async {
    await initializeDIContainer(
      rootInitializers(
        config: () async => _config.replaceFirst(
          '"latencyMs":0',
          '"latencyMs":250',
        ),
        storageDirectory: storage,
      ),
    );
    final latency = diContainer<MockBackend>().latency;
    expect(latency.base, const Duration(milliseconds: 250));
    expect(latency.jitter, Duration.zero);
  });

  test('appStorageDirectory sits in the data container', () {
    final dir = appStorageDirectory();
    expect(dir.path, endsWith('/Library/Application Support/mc_storage'));
    expect(dir.path, startsWith(Directory.systemTemp.parent.path));
  });

  test('AppLocations', () {
    expect(AppLocations.home, '/');
    expect(AppLocations.placeholder(7), '/placeholder/7');
  });
}
