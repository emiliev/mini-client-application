// T-0063: settings_appearance inside the real app (the full root list, every
// wiring and the app's mock domains): the Settings entry on home, the whole
// app re-theming at once (P1-22 AC6), the choice surviving a restart signed
// out and signed in, and the cold deep link with home below it.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _home = Key('home.placeholder');
const _settingsBody = ValueKey<String>('settings_appearance.body');
const _charactersGrid = ValueKey<String>('characters_list.grid');
const _dark = ValueKey<String>('settings_appearance.theme.dark');
const _light = ValueKey<String>('settings_appearance.theme.light');

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('settings_route_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  /// Real file I/O (the session) completes only in real time (F-0038):
  /// alternate real time and settling until [done].
  Future<void> settleIo(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
    expect(done(), isTrue, reason: 'the app got there');
  }

  /// A launch of the app on [storage]: a new root container and a new mocked
  /// backend (it forgets everything, as the app's does when it is killed).
  Future<void> boot(WidgetTester tester, {String? coldStartLink}) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    if (coldStartLink != null) {
      links.offer(coldStartLink);
    }
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: McFixtureAssetBundle(),
        child: MiniClientApp(
          links: links,
          initializers: (routerRef) => rootInitializers(
            config: () async => _config,
            storageDirectory: storage,
            monitoringSinks: [InMemorySink()],
            mockDomains: appMockDomains,
            routerRef: routerRef,
            wirings: wiringInitializers,
          ),
        ),
      ),
    );
    await tester.pump();
    await settleIo(
      tester,
      () =>
          find.byType(Navigator).evaluate().isNotEmpty &&
          find.byKey(const ValueKey('mc.router')).evaluate().isNotEmpty,
    );
  }

  /// Kills the app: the widget tree and the root container go; the storage
  /// directory stays.
  Future<void> kill(WidgetTester tester) async {
    await diContainer<Appearance>().settled();
    await tester.pumpWidget(const SizedBox());
    await resetDIContainer();
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  Brightness brightnessOf(WidgetTester tester, Key key) =>
      Theme.of(tester.element(find.byKey(key))).brightness;

  Future<void> tapHome(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, Key segment) async {
    await tester.tap(find.byKey(segment));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String email) async {
    final result = await tester.runAsync(
      () => diContainer<AuthApi>().signIn(
        email: email,
        password: email.startsWith('collector') ? 'vault-7' : 'marvelous',
      ),
    );
    expect(result?.getOrNull(), isNotNull, reason: '$email signed in');
    await tester.pumpAndSettle();
  }

  /// The account's copy as the app's mocked backend holds it.
  Future<Object?> accountTheme(WidgetTester tester, String userId) async {
    final response = await tester.runAsync(
      () => diContainer<MockBackend>().createDio().get<Map<String, Object?>>(
        'v1/me/preferences',
        options: Options(
          headers: {'Authorization': 'Bearer mc-access-$userId-1'},
        ),
      ),
    );
    return response?.data?['themeMode'];
  }

  testWidgets("T-0063-AC6 home's Settings entry opens the appearance, and "
      'Dark re-themes the whole app at once: home and the characters list '
      'render dark, with no restart', (tester) async {
    await boot(tester);
    expect(brightnessOf(tester, _home), Brightness.light);

    await tapHome(tester, 'Settings');
    expect(
      router(tester).state.uri.toString(),
      AppLocations.settingsAppearance,
    );
    expect(find.byKey(_settingsBody), findsOneWidget);

    await choose(tester, _dark);
    expect(brightnessOf(tester, _settingsBody), Brightness.dark);
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
    expect(brightnessOf(tester, _home), Brightness.dark, reason: 'home');

    await tapHome(tester, 'Characters');
    expect(find.byKey(_charactersGrid), findsOneWidget);
    expect(
      brightnessOf(tester, _charactersGrid),
      Brightness.dark,
      reason: 'another feature',
    );
  });

  testWidgets('T-0063-AC6 signed out, the choice survives a restart: the '
      'next launch is dark from its first routed frame', (tester) async {
    await boot(tester);
    await tapHome(tester, 'Settings');
    await choose(tester, _dark);
    await kill(tester);

    await boot(tester);
    expect(brightnessOf(tester, _home), Brightness.dark);
    await tapHome(tester, 'Settings');
    expect(
      Theme.of(tester.element(find.byKey(_dark))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('T-0063-AC6 signed in, the choice survives a restart through '
      'the account: Light, killed and relaunched, is still Light, and the '
      'account holds Light', (tester) async {
    await boot(tester);
    await signIn(tester, 'collector@mini-client.test');
    await tapHome(tester, 'Settings');
    expect(
      brightnessOf(tester, _settingsBody),
      Brightness.dark,
      reason: "the collector's seed",
    );
    await choose(tester, _light);
    await diContainer<Appearance>().settled();
    expect(await accountTheme(tester, 'u-101'), 'light');
    await kill(tester);

    await boot(tester);
    expect(diContainer<SessionReader>().userId, 'u-101');
    await settleIo(
      tester,
      () =>
          diContainer<Appearance>().snapshot.status ==
          AppearanceSyncStatus.synced,
    );
    expect(brightnessOf(tester, _home), Brightness.light);
    // The new process's backend had forgotten it; the device sent it again.
    expect(await accountTheme(tester, 'u-101'), 'light');
  });

  testWidgets('T-0063-AC5 miniclient://app/settings/appearance cold opens the '
      'settings with home below, and Back goes home', (tester) async {
    await boot(tester, coldStartLink: 'miniclient://app/settings/appearance');

    expect(
      router(tester).state.uri.toString(),
      AppLocations.settingsAppearance,
    );
    // The flow opens its first page once its container is ready.
    await settleIo(
      tester,
      () => find.byKey(_settingsBody).evaluate().isNotEmpty,
    );
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });
}
