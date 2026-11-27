// T-0053-AC1 and AC3: the DI initializer, consent from config and from the
// saved choice, and the lifecycle hook.
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';

import 'support.dart';

AppConfig _config(String? consent) => AppConfig(
  env: 'test',
  backend: const BackendConfig(
    seed: 1,
    latency: Duration.zero,
    scenario: 'happy',
  ),
  apiBaseUrl: 'https://x.invalid/',
  build: '1',
  analytics: consent == null
      ? const AnalyticsConfig()
      : AnalyticsConfig(defaultConsent: consent),
);

void main() {
  late Directory dir;
  late InMemorySink monitoringSink;
  late DateTime now;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = Directory.systemTemp.createTempSync('mc_analytics_di');
    monitoringSink = InMemorySink();
    now = DateTime.utc(2026, 11, 27, 9);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<GetIt> boot({
    String? consent,
    List<AnalyticsSink>? sinks,
    bool observeLifecycle = true,
  }) async {
    final getIt = GetIt.asNewInstance();
    for (final init in <McDIInitializer>[
      McDIInitializer(
        (g, _) => g.registerSingleton<AppConfig>(_config(consent)),
      ),
      McDIInitializer(
        (g, _) => g.registerSingleton<Monitoring>(Monitoring([monitoringSink])),
      ),
      StorageDIInitializer(dir),
      AnalyticsDIInitializer(
        sinks: sinks,
        random: Random(2),
        clock: () => now,
        debugMode: true,
        observeLifecycle: observeLifecycle,
      ),
    ]) {
      await init.init(getIt);
    }
    return getIt;
  }

  test(
    'T-0053-AC1 the default consent is unknown without a config value',
    () async {
      final getIt = await boot();

      expect(getIt<Analytics>().consent, AnalyticsConsent.unknown);
      await getIt.reset();
    },
  );

  test(
    'T-0053-AC1 the config default applies: granted in dev and e2e',
    () async {
      final sink = InMemoryAnalyticsSink();
      final getIt = await boot(consent: 'granted', sinks: [sink]);

      getIt<Analytics>().track(const AnalyticsEvent('a'));
      await settle();

      expect(getIt<Analytics>().consent, AnalyticsConsent.granted);
      expect(sink.events.map((e) => e.name), [sessionStartEventName, 'a']);
      await getIt.reset();
    },
  );

  test('T-0053-AC1 an unrecognised config value does not grant', () async {
    final getIt = await boot(consent: 'yes');

    expect(getIt<Analytics>().consent, AnalyticsConsent.unknown);
    await getIt.reset();
  });

  test('T-0053-AC1 a saved denial beats a granted config default across a '
      'restart', () async {
    final first = await boot(consent: 'granted');
    await first<Analytics>().setConsent(AnalyticsConsent.denied);
    await first.reset();

    final second = await boot(consent: 'granted');

    expect(second<Analytics>().consent, AnalyticsConsent.denied);
    await second.reset();
  });

  test('T-0053-AC1 a saved grant beats an unknown default', () async {
    final first = await boot();
    await first<Analytics>().setConsent(AnalyticsConsent.granted);
    await first.reset();

    final second = await boot();

    expect(second<Analytics>().consent, AnalyticsConsent.granted);
    await second.reset();
  });

  test('T-0053-AC1 boot reads no file when nothing was saved', () async {
    final missing = Directory('${dir.path}/never-created');
    final getIt = GetIt.asNewInstance();
    for (final init in <McDIInitializer>[
      McDIInitializer((g, _) => g.registerSingleton<AppConfig>(_config(null))),
      McDIInitializer(
        (g, _) => g.registerSingleton<Monitoring>(Monitoring(const [])),
      ),
      StorageDIInitializer(missing),
      AnalyticsDIInitializer(debugMode: true),
    ]) {
      await init.init(getIt);
    }

    expect(getIt<Analytics>().consent, AnalyticsConsent.unknown);
    expect(missing.existsSync(), isFalse);
    await getIt.reset();
  });

  test('T-0053-AC3 the default sink forwards to monitoring', () async {
    final getIt = await boot(consent: 'granted');

    getIt<Analytics>().screen('home');
    await settle();

    expect(
      monitoringSink.entries.whereType<EventEntry>().map((e) => e.name),
      [sessionStartEventName, screenViewEventName],
    );
    await getIt.reset();
  });

  test('T-0053-AC3 the app lifecycle rotates the session', () async {
    final getIt = await boot();
    final analytics = getIt<Analytics>();
    final first = analytics.sessionId;
    final binding = TestWidgetsFlutterBinding.instance;

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 30));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(analytics.sessionId, isNot(first));
    await getIt.reset();
  });

  test(
    'T-0053-AC3 disposing the container stops observing the lifecycle',
    () async {
      final getIt = await boot();
      final analytics = getIt<Analytics>();
      await getIt.reset();
      final first = analytics.sessionId;
      final binding = TestWidgetsFlutterBinding.instance;

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 30));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(analytics.sessionId, first);
      // Not a closed-stream error either.
      await analytics.setConsent(AnalyticsConsent.granted);
    },
  );

  test('T-0053-AC3 observeLifecycle false never observes it', () async {
    final getIt = await boot(observeLifecycle: false);
    final analytics = getIt<Analytics>();
    final first = analytics.sessionId;
    final binding = TestWidgetsFlutterBinding.instance;

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 30));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(analytics.sessionId, first);
    await getIt.reset();
  });

  test(
    'T-0053-AC1 the initializer needs config, monitoring and storage',
    () async {
      final getIt = GetIt.asNewInstance();

      await expectLater(
        Future<void>.sync(() => AnalyticsDIInitializer().init(getIt)),
        throwsA(anything),
      );
    },
  );
}
