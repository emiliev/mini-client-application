// The feature's contract with the app (the one src/ importer, R7): its
// analytics vocabulary (ADR-0012) and a label for every value of the
// app-wide appearance (`mc_appearance`), in every shipped locale. A value
// added to `mc_appearance` without a label here fails to compile (the
// switches are exhaustive) or fails this test.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:settings_appearance/src/domain/settings_analytics.dart';
import 'package:settings_appearance/src/l10n/settings_appearance_l10n.dart';

final class _Recorder implements AnalyticsTracker {
  final List<(String, Map<String, Object>?)> events = [];

  @override
  void trackEvent(String name, [Map<String, Object>? params]) =>
      events.add((name, params));

  @override
  void trackScreen(String name) => events.add(('screen:$name', null));
}

final RegExp _snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

void main() {
  test('T-0063-AC6 settings_changed carries setting and value, spelled as '
      'the identity contract spells the values', () {
    final sut = _Recorder()
      ..themeModeChanged(AppearanceThemeMode.dark)
      ..densityChanged(AppearanceDensity.compact)
      ..reduceMotionChanged(on: true)
      ..reduceMotionChanged(on: false)
      ..resetToDefaults();
    expect([
      for (final e in sut.events) e.$1,
    ], everyElement('settings_changed'));
    expect(
      [for (final e in sut.events) e.$2],
      [
        {'setting': 'theme_mode', 'value': 'dark'},
        {'setting': 'density', 'value': 'compact'},
        {'setting': 'reduce_motion', 'value': 'true'},
        {'setting': 'reduce_motion', 'value': 'false'},
        {'setting': 'reset', 'value': 'defaults'},
      ],
    );
    for (final mode in AppearanceThemeMode.values) {
      final r = _Recorder()..themeModeChanged(mode);
      expect(r.events.single.$2!['value'], mode.wire);
    }
    for (final density in AppearanceDensity.values) {
      final r = _Recorder()..densityChanged(density);
      expect(r.events.single.$2!['value'], density.wire);
    }
  });

  test('T-0063-AC6 every name is valid analytics snake_case, and the first '
      "screen is the route's name", () {
    for (final name in [
      settingsChangedEvent,
      settingsAppearanceScreen,
      settingsAppearanceAboutScreen,
      for (final s in TrackedSetting.values) s.wireName,
    ]) {
      expect(_snakeCase.hasMatch(name), isTrue, reason: name);
      expect(name.length, lessThanOrEqualTo(40), reason: name);
    }
    // account_wiring names the route `settings_appearance` (ADR-0012 §3).
    expect(settingsAppearanceScreen, 'settings_appearance');
    expect(settingsAppearanceAboutScreen, 'settings_appearance_about');
  });

  for (final locale in const [Locale('en'), Locale('de')]) {
    test('T-0063-AC4 every theme mode, density and status has its own label '
        'in ${locale.languageCode}', () {
      final l10n = lookupSettingsAppearanceL10n(locale);
      final labels = [
        l10n.settingsAppearanceThemeSystem,
        l10n.settingsAppearanceThemeLight,
        l10n.settingsAppearanceThemeDark,
        l10n.settingsAppearanceDensityComfortable,
        l10n.settingsAppearanceDensityCompact,
      ];
      expect(labels.toSet(), hasLength(labels.length));
      final statuses = [
        l10n.settingsAppearanceSyncLocal,
        l10n.settingsAppearanceSyncPending,
        l10n.settingsAppearanceSyncSynced,
        l10n.settingsAppearanceSyncOffline,
        l10n.settingsAppearanceSyncConflictResolved,
        l10n.settingsAppearanceSigningIn,
      ];
      expect(statuses.toSet(), hasLength(statuses.length));
      expect(
        AppearanceThemeMode.values.length + AppearanceDensity.values.length,
        labels.length,
        reason: 'one label per value',
      );
      expect(
        AppearanceSyncStatus.values.length + 1,
        statuses.length,
        reason: 'one line per status, plus signing in',
      );
    });
  }
}
