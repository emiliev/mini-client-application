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

/// T-0054-AC4 (P-097), cold `/nope`: the not-found page opens over home with
/// a back button and "Go home". Back leads home in one action. Then a link
/// to the running app (`/comics/abc`, a bad id) gives `[home, not-found]`
/// again, and "Go home" leads home in one action.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0054-AC4 a cold /nope has Back and Go home; a running link '
      'to /comics/abc stacks over home', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/nope',
    );

    startApp(app.main);
    await pumpUntil(tester, find.byKey(_notFound), 'the not-found page');
    expect(find.byKey(_home), findsNothing, reason: 'covered by not-found');
    expect(find.textContaining('/nope'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget, reason: 'a back button');
    expect(find.byKey(_goHome), findsOneWidget, reason: 'Go home');
    await shot(binding, tester, '60_cold_nope_not_found');

    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.byKey(_home), 'home after one Back');
    expect(find.byType(BackButton), findsNothing, reason: 'home is bottom');
    await shot(binding, tester, '60b_cold_nope_back_is_home');

    await pushLink(tester, 'miniclient://app/comics/abc');
    await pumpUntil(tester, find.byKey(_notFound), 'not-found for a bad id');
    expect(find.textContaining('/comics/abc'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await shot(binding, tester, '61_running_bad_comic_not_found');

    await tester.tap(find.byKey(_goHome));
    await pumpUntil(tester, find.byKey(_home), 'home after one Go home');
    expect(find.byType(BackButton), findsNothing, reason: 'home is bottom');
    await shot(binding, tester, '61b_running_go_home');
  });
}
