import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mini_client/main.dart' as app;
import 'package:mini_client/src/pages/placeholder_pages.dart';

const _home = Key('home.placeholder');
const _signInForm = ValueKey<String>('auth_signin.form');
const _demoReader = ValueKey<String>(
  'auth_signin.demo.reader@mini-client.test',
);
const _comicTitle = ValueKey<String>('comics_details.title');

/// Taps the first demo account, then Sign in, on the sign-in form.
Future<void> _signInWithTheDemoAccount(WidgetTester tester) async {
  await tester.tap(find.byKey(_demoReader));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(McFormScaffold.submitKey));
}

/// T-0066-AC4 on a simulator, through the real `main()`: home, Sign in with
/// the demo account, a favourite on a comic, Sign out, then the cold link
/// `miniclient://app/me/lists/new` (the app is relaunched with the link, as
/// `settings_signed_in_test` relaunches): the guard sends the signed-out user
/// to sign-in, and after it the editor opens, with Back leading home. Run
/// through `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0066-AC4 home, Sign in, a favourite, Sign out, then the cold '
      'link to the editor asks for sign-in and opens the editor, and Back '
      'leads home', (tester) async {
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'the home page');
    // An earlier target on this simulator may have left a session.
    if (find.byKey(signOutKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(signOutKey));
      await pumpUntil(tester, find.byKey(signInKey), 'home, signed out');
    }
    expect(find.text('Signed out'), findsOneWidget);
    await shot(binding, tester, '70_home_signed_out');

    await tester.tap(find.byKey(signInKey));
    await pumpUntil(tester, find.byKey(_signInForm), 'the sign-in form');
    expect(find.text('Use a demo account'), findsOneWidget);
    await shot(binding, tester, '71_sign_in_form');
    await _signInWithTheDemoAccount(tester);
    await pumpUntil(tester, find.text('Signed in as u-100'), 'home, signed in');
    expect(find.byKey(_signInForm), findsNothing);
    await shot(binding, tester, '72_home_signed_in');

    // A favourite on a comic: signed in, so no sign-in is asked.
    await pushLink(tester, 'miniclient://app/comics/501500');
    await pumpUntil(tester, find.byKey(_comicTitle), 'the comic page');
    await letArtLoad(tester);
    await tester.tap(find.text('Add to favourites'));
    await pumpUntil(
      tester,
      find.text('Remove from favourites'),
      'the saved favourite',
    );
    expect(find.byKey(_signInForm), findsNothing);
    await shot(binding, tester, '73_favourite_saved');

    await pushLink(tester, 'miniclient://app/');
    await pumpUntil(tester, find.byKey(signOutKey), 'home with Sign out');
    await tester.tap(find.byKey(signOutKey));
    await pumpUntil(tester, find.text('Signed out'), 'home, signed out again');
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
    await shot(binding, tester, '74_home_signed_out_again');

    // The cold link: relaunched with the link, signed out.
    await tester.pumpWidget(const SizedBox());
    await resetDIContainer();
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/me/lists/new',
    );
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_signInForm), 'the guard sign-in form');
    expect(find.byKey(_home), findsNothing, reason: 'the link was the start');
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
    await shot(binding, tester, '75_cold_link_sign_in');

    await _signInWithTheDemoAccount(tester);
    await pumpUntil(tester, find.text('Step 1 of 3'), 'the editor, after it');
    expect(find.text('New reading list'), findsOneWidget);
    expect(diContainer<SessionReader>().userId, 'u-100');
    await shot(binding, tester, '76_editor_after_sign_in');

    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(tester, find.byKey(_home), 'home, after Back');
    expect(find.text('Signed in as u-100'), findsOneWidget);
    await shot(binding, tester, '77_back_to_home');
  });
}
