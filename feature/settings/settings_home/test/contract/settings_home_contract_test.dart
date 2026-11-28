// The feature's contract with the app (the one src/ importer, R7): its screen
// name (ADR-0012) and a label for every value of the app-wide theme mode
// (`mc_appearance`), in every shipped locale. A value added to
// `mc_appearance` without a label here fails to compile (the page's switch is
// exhaustive) or fails this test.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:settings_home/src/domain/settings_home_analytics.dart';
import 'package:settings_home/src/l10n/settings_home_l10n.dart';

final RegExp _snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

void main() {
  test("T-0070-AC1 the screen is valid analytics snake_case and equals the "
      "route's name", () {
    expect(_snakeCase.hasMatch(settingsHomeScreen), isTrue);
    // account_wiring names the route `settings_home` (ADR-0012 §3).
    expect(settingsHomeScreen, 'settings_home');
  });

  test('T-0070-AC4 the version line reads exactly as written in each '
      'locale', () {
    expect(
      lookupSettingsHomeL10n(
        const Locale('en'),
      ).settingsHomeAboutVersionValue('1.2.3', '7'),
      '1.2.3 (build 7)',
    );
    expect(
      lookupSettingsHomeL10n(
        const Locale('de'),
      ).settingsHomeAboutVersionValue('1.2.3', '7'),
      '1.2.3 (Build 7)',
    );
    expect(
      lookupSettingsHomeL10n(const Locale('en')).settingsHomeSignedInAs('Ada'),
      'Signed in as Ada',
    );
    expect(
      lookupSettingsHomeL10n(const Locale('de')).settingsHomeSignedInAs('Ada'),
      'Angemeldet als Ada',
    );
  });

  for (final locale in const [Locale('en'), Locale('de')]) {
    test('T-0070-AC4 every theme mode has its own label in '
        '${locale.languageCode}', () {
      final l10n = lookupSettingsHomeL10n(locale);
      final labels = [
        l10n.settingsHomeThemeSystem,
        l10n.settingsHomeThemeLight,
        l10n.settingsHomeThemeDark,
      ];
      expect(labels.toSet(), hasLength(labels.length));
      expect(
        AppearanceThemeMode.values.length,
        labels.length,
        reason: 'one label per value',
      );
    });
  }
}
