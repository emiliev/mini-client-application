// T-0063 (ADR-0013): McApp follows the app-wide appearance. A change
// re-themes every routed page at once, Compact is every theme's visual
// density, and Reduce motion turns the DS animations off (the charts'
// draw-in), on top of the platform's own setting.
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';

/// An appearance the test drives.
final class _Appearance implements AppearanceReader {
  _Appearance([AppearancePreferences initial = AppearancePreferences.defaults])
    : _snapshot = AppearanceSnapshot(
        preferences: initial,
        status: AppearanceSyncStatus.local,
      );

  final StreamController<AppearanceSnapshot> _changes =
      StreamController<AppearanceSnapshot>.broadcast();
  AppearanceSnapshot _snapshot;
  int listeners = 0;

  @override
  AppearanceSnapshot get snapshot => _snapshot;

  @override
  Stream<AppearanceSnapshot> get changes {
    listeners++;
    return _changes.stream;
  }

  void set(AppearancePreferences preferences) {
    _snapshot = AppearanceSnapshot(
      preferences: preferences,
      status: AppearanceSyncStatus.local,
    );
    _changes.add(_snapshot);
  }
}

const _pageKey = Key('page');
const _chartKey = Key('chart');

/// A routed page that reports what it is built with.
final class _Seen {
  Brightness? brightness;
  VisualDensity? density;
  bool? disableAnimations;
}

GoRouter Function(String) _router(_Seen seen, {bool chart = false}) =>
    (initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            seen
              ..brightness = Theme.of(context).brightness
              ..density = Theme.of(context).visualDensity
              ..disableAnimations = MediaQuery.disableAnimationsOf(context);
            return Scaffold(
              key: _pageKey,
              body: chart
                  ? const McDonutChart(
                      key: _chartKey,
                      animate: true,
                      semanticLabel: 'chart',
                      emptyMessage: 'empty',
                      data: [
                        McDonutSegment(label: 'a', value: 1),
                        McDonutSegment(label: 'b', value: 2),
                      ],
                    )
                  : const Text('home'),
            );
          },
        ),
      ],
    );

Future<void> _pumpApp(
  WidgetTester tester, {
  required _Seen seen,
  AppearanceReader? appearance,
  bool chart = false,
  bool platformDisablesAnimations = false,
}) async {
  final links = PendingLinks.install(tester.binding);
  addTearDown(links.detach);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: platformDisablesAnimations);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    McApp(
      boot: () async {},
      router: _router(seen, chart: chart),
      links: links,
      appearance: () => appearance,
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(resetDIContainer);
  tearDown(resetDIContainer);

  testWidgets('T-0063-AC6 a choice re-themes the routed app at once, with no '
      'restart', (tester) async {
    final seen = _Seen();
    final appearance = _Appearance();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pumpApp(tester, seen: seen, appearance: appearance);
    expect(seen.brightness, Brightness.light, reason: 'System, a light device');
    final router = find.byKey(const ValueKey('mc.router'));
    final appElement = tester.element(router);

    appearance.set(
      const AppearancePreferences(themeMode: AppearanceThemeMode.dark),
    );
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.brightness, Brightness.dark);
    expect(
      tester.element(router),
      same(appElement),
      reason: 'the same app, re-themed (no new router)',
    );

    appearance.set(
      const AppearancePreferences(themeMode: AppearanceThemeMode.light),
    );
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.brightness, Brightness.light);

    // System follows the platform.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    appearance.set(AppearancePreferences.defaults);
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.brightness, Brightness.dark);
  });

  testWidgets('T-0063-AC6 the saved choice is the first routed frame: dark '
      'from the start', (tester) async {
    final seen = _Seen();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pumpApp(
      tester,
      seen: seen,
      appearance: _Appearance(
        const AppearancePreferences(themeMode: AppearanceThemeMode.dark),
      ),
    );
    expect(seen.brightness, Brightness.dark);
  });

  testWidgets('T-0063-AC4 Compact is the visual density of every theme, '
      'and Comfortable the platform default', (tester) async {
    final seen = _Seen();
    final appearance = _Appearance();
    await _pumpApp(tester, seen: seen, appearance: appearance);
    expect(seen.density, VisualDensity.standard);

    appearance.set(
      const AppearancePreferences(
        themeMode: AppearanceThemeMode.dark,
        density: AppearanceDensity.compact,
      ),
    );
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.density, VisualDensity.compact);
    expect(seen.brightness, Brightness.dark);

    appearance.set(
      const AppearancePreferences(density: AppearanceDensity.compact),
    );
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.density, VisualDensity.compact, reason: 'the light theme too');
  });

  testWidgets('T-0063-AC6 Reduce motion turns animations off for every '
      'routed page; off, the platform decides', (tester) async {
    final seen = _Seen();
    final appearance = _Appearance();
    await _pumpApp(tester, seen: seen, appearance: appearance);
    expect(seen.disableAnimations, isFalse);

    appearance.set(const AppearancePreferences(reduceMotion: true));
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.disableAnimations, isTrue);

    appearance.set(AppearancePreferences.defaults);
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(seen.disableAnimations, isFalse);
  });

  testWidgets("T-0063-AC6 Reduce motion off never turns the platform's own "
      'setting back on', (tester) async {
    final seen = _Seen();
    await _pumpApp(
      tester,
      seen: seen,
      appearance: _Appearance(),
      platformDisablesAnimations: true,
    );
    expect(seen.disableAnimations, isTrue);
  });

  for (final reduce in [false, true]) {
    testWidgets('T-0063-AC6 the charts draw in ${reduce ? 'not at all' : ''}'
        '${reduce ? ' under Reduce motion' : 'without Reduce motion'}', (
      tester,
    ) async {
      final seen = _Seen();
      await _pumpApp(
        tester,
        seen: seen,
        chart: true,
        appearance: _Appearance(AppearancePreferences(reduceMotion: reduce)),
      );
      expect(find.byKey(_chartKey), findsOneWidget);
      expect(
        tester.hasRunningAnimations,
        !reduce,
        reason: reduce ? 'no draw-in' : 'the draw-in runs',
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('T-0063-AC6 with no appearance the app keeps the defaults, and '
      'the root container is where McApp looks by default', (tester) async {
    final seen = _Seen();
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    expect(McApp.rootAppearance(), isNull);
    final appearance = _Appearance(
      const AppearancePreferences(themeMode: AppearanceThemeMode.dark),
    );
    await tester.pumpWidget(
      McApp(
        boot: () => initializeDIContainer([
          McDIInitializer(
            (getIt, _) => getIt.registerSingleton<AppearanceReader>(appearance),
          ),
        ]),
        router: _router(seen),
        links: links,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(McApp.rootAppearance(), same(appearance));
    expect(seen.brightness, Brightness.dark);
    expect(appearance.listeners, 1);

    await tester.pumpWidget(const SizedBox());
    final none = _Seen();
    await resetDIContainer();
    final links2 = PendingLinks.install(tester.binding);
    addTearDown(links2.detach);
    await tester.pumpWidget(
      McApp(boot: () async {}, router: _router(none), links: links2),
    );
    await tester.pump();
    await tester.pump();
    expect(none.density, VisualDensity.standard);
    expect(none.disableAnimations, isFalse);
  });

  testWidgets('T-0063-AC6 a change after the app is gone is ignored', (
    tester,
  ) async {
    final seen = _Seen();
    final appearance = _Appearance();
    await _pumpApp(tester, seen: seen, appearance: appearance);
    await tester.pumpWidget(const SizedBox());
    appearance.set(
      const AppearancePreferences(themeMode: AppearanceThemeMode.dark),
    );
    // The theme cross-fades (MaterialApp's theme animation).
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
