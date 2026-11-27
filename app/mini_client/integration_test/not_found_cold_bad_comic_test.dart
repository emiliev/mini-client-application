import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _notFound = Key('not.found');
const _goHome = Key('not.found.home');

/// T-0054-AC4 (P-097), cold `/comics/abc` (a bad id): not-found with a back
/// button and "Go home" over home; "Go home" leads home in one action.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0054-AC4 a cold /comics/abc has Back and Go home', (
    tester,
  ) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/comics/abc',
    );

    startApp(app.main);
    await pumpUntil(tester, find.byKey(_notFound), 'the not-found page');
    expect(find.byKey(_home), findsNothing, reason: 'covered by not-found');
    expect(find.textContaining('/comics/abc'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget, reason: 'a back button');
    await shot(binding, tester, '62_cold_bad_comic_not_found');

    await tester.tap(find.byKey(_goHome));
    await pumpUntil(tester, find.byKey(_home), 'home after one Go home');
    expect(find.byType(BackButton), findsNothing, reason: 'home is bottom');
    expect(find.byKey(_notFound), findsNothing);
    await shot(binding, tester, '62b_cold_bad_comic_go_home');
  });
}
