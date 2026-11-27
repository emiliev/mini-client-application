import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _storeBody = ValueKey<String>('store_home.body');

/// T-0056-AC5's first deep link: `miniclient://app/store` cold opens the
/// store over home (the file-drop start link: `simctl openurl` shows a
/// prompt no script can answer, F-0020); Back goes home.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0056-AC5 the cold link miniclient://app/store opens the '
      'store, and Back goes home', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/store',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_storeBody),
        matching: find.text('Amber Frontier #2'),
      ),
      'the linked store',
    );
    expect(find.byKey(_home), findsNothing, reason: 'the link was the start');
    expect(find.byType(BackButton), findsWidgets, reason: 'home is below');
    await letArtLoad(tester);
    await shot(binding, tester, '47_deep_link_store');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_home), 'home, after Back');
    await shot(binding, tester, '47b_back_from_store_is_home');
  });
}
