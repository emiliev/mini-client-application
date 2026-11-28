import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _settingsBody = ValueKey<String>('settings_appearance.body');
const _indexBody = ValueKey<String>('settings_home.body');

/// T-0063-AC5's deep link: `miniclient://app/settings/appearance` cold opens
/// the settings over the settings index over home (the file-drop start link,
/// F-0020); Back goes to the index (T-0070), then home.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0063-AC5 T-0070-AC4 the cold link '
      'miniclient://app/settings/appearance opens the settings, and Back '
      'goes to the index, then home', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/settings/appearance',
    );

    startApp(app.main);
    await pumpUntil(tester, find.byKey(_settingsBody), 'the linked settings');
    expect(find.byKey(_home), findsNothing, reason: 'the link was the start');
    expect(find.byType(BackButton), findsWidgets, reason: 'home is below');
    await tester.pump(const Duration(milliseconds: 500));
    await shot(binding, tester, '68_deep_link_settings');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_indexBody), 'the index, after Back');
    await shot(binding, tester, '68b_back_from_appearance_is_settings');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_home), 'home, after the second Back');
    await shot(binding, tester, '68c_back_from_settings_is_home');
  });
}
