import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _settingsBody = ValueKey<String>('settings_appearance.body');
const _dark = ValueKey<String>('settings_appearance.theme.dark');
const _charactersGrid = ValueKey<String>('characters_list.grid');

Brightness _brightness(WidgetTester tester, Key key) =>
    Theme.of(tester.element(find.byKey(key))).brightness;

Future<void> _openFromHome(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(label));
}

/// T-0063-AC5 on a simulator, through the real `main()`: home → Settings →
/// Dark; the home page and another feature (the characters list) render
/// dark; then the app is relaunched and is still dark.
///
/// The relaunch is a second `main()` in the same process, over the same
/// data container: `tool/e2e_ios.sh` uninstalls the app before each target
/// (T-0055), so a kill between two targets would also wipe its storage. The
/// widget tree and the root container are torn down first, so the second
/// launch boots from the saved files only, with a fresh mocked backend, as
/// after a kill.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0063-AC5 home to Settings, Dark: home and the characters '
      'list render dark; relaunched, still dark', (tester) async {
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'the home page');
    final lightHome = _brightness(tester, _home);
    await _openFromHome(tester, 'Settings');
    await pumpUntil(tester, find.byKey(_settingsBody), 'the settings');
    await tester.pump(const Duration(milliseconds: 500));
    await shot(binding, tester, '60_settings_appearance');

    await tester.tap(find.byKey(_dark));
    await letArtLoad(tester, const Duration(seconds: 1));
    expect(_brightness(tester, _settingsBody), Brightness.dark);
    await shot(binding, tester, '61_settings_dark');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_home), 'home, after Back');
    await letArtLoad(tester, const Duration(seconds: 1));
    expect(_brightness(tester, _home), Brightness.dark);
    expect(lightHome, Brightness.light, reason: 'it started light');
    await shot(binding, tester, '62_home_dark');

    await _openFromHome(tester, 'Characters');
    await pumpUntil(tester, find.byKey(_charactersGrid), 'the characters');
    await letArtLoad(tester);
    expect(_brightness(tester, _charactersGrid), Brightness.dark);
    await shot(binding, tester, '63_characters_dark');

    // Relaunch: the app goes, its files stay.
    await tester.pumpWidget(const SizedBox());
    await resetDIContainer();
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'home, relaunched');
    await letArtLoad(tester, const Duration(seconds: 1));
    expect(_brightness(tester, _home), Brightness.dark, reason: 'still dark');
    await shot(binding, tester, '64_relaunched_still_dark');
  });
}
