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
    '"build":"1"}';

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
    'T-0021-AC2 boot taking longer than 10 s shows the timeout state with '
    'Retry',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final held = Completer<void>();
      var taskRuns = 0;
      await tester.pumpWidget(
        McApp(
          boot: () {
            taskRuns++;
            return held.future;
          },
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

      // Retry waits for the same initialisation; it never starts a second.
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byKey(BootPage.loadingKey), findsOneWidget);
      held.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
      expect(taskRuns, 1);
    },
  );

  testWidgets(
    'T-0021-AC2 a boot that finishes while the timeout shows is picked up '
    'by Retry',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final held = Completer<void>();
      await tester.pumpWidget(
        McApp(boot: () => held.future, router: _router, links: links),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(find.byKey(BootPage.timedOutKey), findsOneWidget);

      // The late result alone does not leave the timeout screen.
      held.complete();
      await tester.pump();
      expect(find.byKey(BootPage.timedOutKey), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
    },
  );

  test('T-0021-AC1 a failed run is discarded, so Retry runs the task again '
      'while a timed-out run is reused', () async {
    var runs = 0;
    var fail = true;
    final bloc = BootBloc(
      task: () async {
        runs++;
        if (fail) {
          fail = false;
          throw StateError('first');
        }
      },
    )..start();
    await pumpEventQueue();
    expect(bloc.state, isA<BootFailed>());
    expect((bloc.state as BootFailed).attempt, 1);
    bloc.retry();
    expect(bloc.state, isA<BootBooting>());
    await pumpEventQueue();
    expect(bloc.state, isA<BootReady>());
    expect(runs, 2);
    expect(bloc.taskRuns, 2);
    // Terminal: retry and start do nothing.
    bloc
      ..retry()
      ..start();
    expect(runs, 2);
    bloc.dispose();
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
    expect(
      diContainer<Dio>().httpClientAdapter,
      same(diContainer<MockBackend>().adapter),
    );
    expect(diContainer.isRegistered<EventBus>(), isTrue);
    await diContainer<Monitoring>().log('hi');
    expect(sink.entries, hasLength(1));
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
