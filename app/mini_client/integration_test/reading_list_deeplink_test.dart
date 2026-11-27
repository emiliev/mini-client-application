import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;
import 'package:mini_client/src/pages/placeholder_pages.dart';

/// T-0048-AC5's deep link: `miniclient://app/me/lists/new` opens the
/// reading-list editor through the file-drop start link (F-0020: `simctl
/// openurl` shows a prompt no script can answer). The editor asks to sign in
/// first (the guard sends a signed-out user to the sign-in, T-0066); after the
/// sign-in it shows step 1. Then a link to edit list `l-1`
/// sent to the running app opens that list, filled in.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0048-AC5 the deep link miniclient://app/me/lists/new opens '
      'the editor', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/me/lists/new',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey<String>('auth_signin.form') ||
            (w is Text && w.data == 'Step 1 of 3'),
      ),
      'the linked editor, or the sign-in the guard asks for',
    );
    expect(
      find.byKey(const Key('home.placeholder')),
      findsNothing,
      reason: 'the link, not home, was the start location',
    );
    // The session is kept on disk: signed in by an earlier target, the
    // editor opens at once; otherwise it asks first.
    if (find
        .byKey(const ValueKey<String>('auth_signin.form'))
        .evaluate()
        .isNotEmpty) {
      await shot(binding, tester, '36b_guard_sign_in_form');
      await tester.tap(
        find.byKey(
          const ValueKey<String>('auth_signin.demo.reader@mini-client.test'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(McFormScaffold.submitKey));
    }
    await pumpUntil(tester, find.text('Step 1 of 3'), 'the linked editor');
    expect(find.text('New reading list'), findsOneWidget);
    expect(
      find.byType(BackButton),
      findsWidgets,
      reason: 'T-0049-AC1: the cold link has a back button',
    );
    await shot(binding, tester, '37_deep_link_new_list');
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'T-0049-AC1: home, after Back from the cold link',
    );
    await shot(binding, tester, '37b_back_from_new_list_is_home');
    // AC3: home's New reading list button opens the editor again.
    await tester.tap(find.byKey(newReadingListKey));
    await pumpUntil(tester, find.text('Step 1 of 3'), 'the editor from home');
    await pushLink(tester, 'miniclient://app/');
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'home, replacing the open editor',
    );
    await tester.tap(find.byKey(newReadingListKey));
    await pumpUntil(
      tester,
      find.text('Step 1 of 3'),
      'T-0049-AC3: the editor again, after a link replaced it',
    );
    await shot(binding, tester, '37c_editor_after_link_replaced_it');

    await pushLink(tester, 'miniclient://app/me/lists/l-1/edit');
    await pumpUntil(
      tester,
      find.text('Edit reading list'),
      'the linked list in the editor',
    );
    await pumpUntil(
      tester,
      find.text('Spider-Verse Starter'),
      'the list filled in',
    );
    await shot(binding, tester, '38_link_edit_list');
  });
}
