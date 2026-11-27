import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _settingsBody = ValueKey<String>('settings_appearance.body');
const _syncStatus = ValueKey<String>('settings_appearance.sync');
const _syncCta = ValueKey<String>('settings_appearance.sync_cta');
const _light = ValueKey<String>('settings_appearance.theme.light');

Brightness _brightness(WidgetTester tester, Key key) =>
    Theme.of(tester.element(find.byKey(key))).brightness;

/// The signed-in user's account copy, as the app's mocked backend holds it.
Future<Object?> _accountTheme() async {
  final userId = diContainer<SessionReader>().userId!;
  final response = await diContainer<MockBackend>()
      .createDio()
      .get<Map<String, Object?>>(
        'v1/me/preferences',
        options: Options(
          headers: {'Authorization': 'Bearer mc-access-$userId-1'},
        ),
      );
  return response.data!['themeMode'];
}

/// T-0063-AC5 signed in, on a simulator: Settings → "Sync across devices" →
/// the fixture sign-in sheet → Light; the account holds Light; relaunched
/// (as in `settings_journey_test`: a second `main()` over the same files and
/// a fresh mocked backend), it is still Light and the account holds Light
/// again (the device sends the copy the new backend lost, ADR-0013).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0063-AC5 signed in: Light, relaunched, still Light, and the '
      'account holds Light', (tester) async {
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'the home page');
    await tester.scrollUntilVisible(
      find.text('Settings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Settings'));
    await pumpUntil(tester, find.byKey(_settingsBody), 'the settings');

    await tester.tap(find.byKey(_syncCta));
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('auth_signin.form')),
      'the sign-in form',
    );
    expect(
      find.text('Sign in to sync your appearance across devices.'),
      findsOneWidget,
    );
    await shot(binding, tester, '65_sync_sign_in_form');
    await tester.tap(
      find.byKey(
        const ValueKey<String>('auth_signin.demo.reader@mini-client.test'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(McFormScaffold.submitKey));
    await pumpUntil(
      tester,
      find.text('Synced with your account.'),
      'the synced status',
    );
    await tester.tap(find.byKey(_light));
    await pumpUntil(
      tester,
      find.text('Synced with your account.'),
      'Light synced',
    );
    await letArtLoad(tester, const Duration(seconds: 1));
    expect(_brightness(tester, _settingsBody), Brightness.light);
    expect(
      tester.widget<Text>(find.byKey(_syncStatus)).data,
      'Synced with your account.',
    );
    expect(await _accountTheme(), 'light');
    await shot(binding, tester, '66_signed_in_light_synced');

    await tester.pumpWidget(const SizedBox());
    await resetDIContainer();
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'home, relaunched');
    expect(diContainer<SessionReader>().isSignedIn, isTrue);
    final appearance = diContainer<AppearanceReader>();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (appearance.snapshot.status != AppearanceSyncStatus.synced) {
      if (DateTime.now().isAfter(deadline)) {
        fail('the relaunched app never synced: ${appearance.snapshot}');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await letArtLoad(tester, const Duration(seconds: 1));
    expect(_brightness(tester, _home), Brightness.light, reason: 'Light');
    expect(
      appearance.snapshot.preferences.themeMode,
      AppearanceThemeMode.light,
      reason: 'still Light, not the System it would fall back to',
    );
    expect(await _accountTheme(), 'light');
    await shot(binding, tester, '67_relaunched_still_light');
  });
}
