import 'dart:async';
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:mini_client/src/mini_client_app.dart';
import 'package:mini_client/src/router/app_router.dart';
import 'package:mini_client/src/router/app_routes.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid","build":"1"}';

/// What iOS sends for `simctl openurl` once the app runs.
Future<void> _pushLink(WidgetTester tester, String location) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );

/// Records every container an initializer ran against.
class _Recording {
  final Map<String, List<GetIt>> runs = {};

  McDIInitializer wrap(String name, McDIInitializer inner) =>
      McDIInitializer((GetIt getIt, String? environment) async {
        (runs[name] ??= []).add(getIt);
        await inner.init(getIt);
      });
}

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('mini_client_app_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  List<McDIInitializer> roots({List<McDIInitializer> extra = const []}) =>
      rootInitializers(
        config: () async => _config,
        storageDirectory: storage,
        monitoringSinks: [InMemorySink()],
        wirings: [...wiringInitializers, ...extra],
      );

  testWidgets(
    'T-0021-AC4 a cold-start link held during boot shows its route once boot '
    'succeeds, and no route builder or redirect ran before ready',
    (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue =
          'miniclient://app/placeholder/7';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final probe = McRouteProbe();
      final hold = Completer<void>();

      await tester.pumpWidget(
        MiniClientApp(
          links: links,
          probe: probe,
          initializers: roots(
            extra: [McDIInitializer((_, _) => hold.future)],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Boot is held: only BootPage, no router, nothing route-side ran.
      expect(find.byKey(BootPage.loadingKey), findsOneWidget);
      expect(find.byType(Router<Object>), findsNothing);
      expect(probe.builds, isEmpty);
      expect(probe.redirects, isEmpty);
      expect(links.pending, '/placeholder/7');

      hold.complete();
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Placeholder detail 7'), findsOneWidget);
      expect(find.byType(BootPage), findsNothing);
      expect(probe.beforeReady, 0);
      expect(probe.builds, contains('placeholder'));
      expect(probe.redirects, isNotEmpty);
      expect(links.isAttached, isFalse);
    },
  );

  testWidgets(
    'T-0021-AC4 a link pushed while boot is held wins and is not seen by the '
    'boot navigator',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final probe = McRouteProbe();
      final hold = Completer<void>();
      await tester.pumpWidget(
        MiniClientApp(
          links: links,
          probe: probe,
          initializers: roots(
            extra: [McDIInitializer((_, _) => hold.future)],
          ),
        ),
      );
      await _pushLink(tester, 'miniclient://app/placeholder/3');
      await tester.pump();
      expect(links.received, 1);
      expect(find.byKey(BootPage.loadingKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      hold.complete();
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Placeholder detail 3'), findsOneWidget);
      expect(probe.beforeReady, 0);

      // After ready, links go to go_router.
      await _pushLink(tester, 'miniclient://app/placeholder/11');
      await tester.pumpAndSettle();
      expect(find.text('Placeholder detail 11'), findsOneWidget);
      expect(links.received, 1);
    },
  );

  testWidgets(
    'T-0021-AC5 with the same link and a failing first boot, Retry replays '
    'the link once and every root type is registered exactly once',
    (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue =
          'miniclient://app/placeholder/7';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final probe = McRouteProbe();
      final recording = _Recording();
      var routersCreated = 0;
      var failures = 1;
      final initializers = [
        for (final (i, init) in roots().indexed) recording.wrap('root$i', init),
        // Last, so the first attempt has registered every root type before
        // it fails: a non-transactional init would then re-register them.
        McDIInitializer((_, _) {
          if (failures-- > 0) {
            throw StateError('first boot fails');
          }
        }),
      ];

      await tester.pumpWidget(
        MiniClientApp(
          links: links,
          probe: probe,
          initializers: initializers,
          router: (initialLocation) {
            routersCreated++;
            return buildAppRouter(initialLocation: initialLocation);
          },
        ),
      );
      await tester.pump();
      expect(find.byKey(BootPage.failedKey), findsOneWidget);
      expect(routersCreated, 0);
      expect(links.takes, 0);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Placeholder detail 7'), findsOneWidget);
      expect(routersCreated, 1);
      expect(links.takes, 1, reason: 'the held link is replayed once');
      expect(probe.beforeReady, 0);
      expect(
        probe.builds.where((b) => b == 'placeholder'),
        hasLength(1),
      );

      // Each root initializer ran once per attempt, into a fresh container
      // per attempt, and the published root holds attempt 2's instances.
      expect(recording.runs.keys, hasLength(roots().length));
      for (final MapEntry(:key, :value) in recording.runs.entries) {
        expect(value, hasLength(2), reason: key);
        expect(identical(value[0], value[1]), isFalse, reason: key);
      }
      final published = recording.runs['root0']![1];
      expect(
        recording.runs.values.every((r) => identical(r[1], published)),
        isTrue,
      );
      final discarded = recording.runs['root0']![0];
      expect(discarded.isRegistered<AppConfig>(), isFalse);
      expect(diContainer<AppConfig>(), same(published<AppConfig>()));
      expect(diContainer<Monitoring>(), same(published<Monitoring>()));
      expect(diContainer<FileStore>(), same(published<FileStore>()));
      expect(diContainer<MockBackend>(), same(published<MockBackend>()));
      expect(diContainer<Dio>(), same(published<Dio>()));
      expect(diContainer<EventBus>(), same(published<EventBus>()));
    },
  );

  testWidgets(
    'T-0021-AC3 a miniclient://app/placeholder link delivered on the '
    'platform navigation channel to the running app shows that route',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      final probe = McRouteProbe();
      await tester.pumpWidget(
        MiniClientApp(links: links, initializers: roots(), probe: probe),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Marvel universe'), findsOneWidget);

      // What the iOS embedder sends for `simctl openurl` (FlutterDeepLinking).
      await _pushLink(tester, 'miniclient://app/placeholder/42');
      await tester.pumpAndSettle();

      expect(find.text('Placeholder detail 42'), findsOneWidget);
      expect(probe.builds, contains('placeholder'));
      // Nested under home, so back returns to the home placeholder.
      final router = GoRouter.of(
        tester.element(find.text('Placeholder detail 42')),
      );
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Marvel universe'), findsOneWidget);
    },
  );

  testWidgets(
    'T-0021-AC4 a link delivered between BootReady and the router\'s first '
    'frame is held and forwarded to go_router, not lost',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      await tester.pumpWidget(
        MiniClientApp(
          links: links,
          initializers: roots(),
          router: (initialLocation) {
            // Ready, but MaterialApp.router has not built yet.
            unawaited(_pushLink(tester, 'miniclient://app/placeholder/99'));
            return buildAppRouter(initialLocation: initialLocation);
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(links.received, 1, reason: 'held, not seen by the boot navigator');
      expect(links.isAttached, isFalse);
      expect(find.text('Placeholder detail 99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T-0021-AC3 a link for another host or scheme shows home, not its path',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      await tester.pumpWidget(
        MiniClientApp(links: links, initializers: roots()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await _pushLink(tester, 'miniclient://evil/placeholder/5');
      await tester.pumpAndSettle();
      expect(find.text('Placeholder detail 5'), findsNothing);
      expect(find.text('Marvel universe'), findsOneWidget);
    },
  );

  testWidgets('the home placeholder shows the bundled config env', (
    tester,
  ) async {
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    await tester.pumpWidget(
      MiniClientApp(links: links, initializers: roots()),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Marvel universe'), findsOneWidget);
    expect(find.text('Config: env=e2e'), findsOneWidget);

    await tester.tap(find.text('Open placeholder 7'));
    await tester.pumpAndSettle();
    expect(find.text('Placeholder detail 7'), findsOneWidget);
  });

  testWidgets('an unknown path shows the not-found page', (tester) async {
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    await tester.pumpWidget(
      MiniClientApp(
        links: links,
        initializers: roots(),
        router: (_) => buildAppRouter(initialLocation: '/nowhere'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Nothing lives at /nowhere'), findsOneWidget);
  });

  test('AppLocations match the typed routes', () {
    expect(AppLocations.home, const HomeRoute().location);
    expect(AppLocations.placeholder(7), const PlaceholderRoute(id: 7).location);
  });

  test('all 7 wirings are composed', () {
    expect(wiringInitializers, hasLength(7));
    expect(appConfigAsset, 'assets/app_config.json');
    final GoRouter router = buildAppRouter(initialLocation: '/');
    addTearDown(router.dispose);
    expect(router.configuration.routes, isNotEmpty);
  });
}
