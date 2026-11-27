import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _details = ValueKey<String>('reading_list_editor.details');
const _review = ValueKey<String>('reading_list_editor.review');
const _comicsError = ValueKey<String>('reading_list_editor.comics.error');

/// The search result of comic [id] in step 2.
ValueKey<String> _result(int id) =>
    ValueKey<String>('reading_list_editor.result.$id');

/// The fixture sign-in sheet, or step 1 when someone is signed in already.
final Finder _sheetOrStep1 = find.byWidgetPredicate(
  (w) =>
      w.key == fixtureSignInSheetKey || (w is Text && w.data == 'Step 1 of 3'),
);

/// The text field labelled [label].
Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField));

/// T-0048-AC5 on a simulator, through the real `main()`: home, New reading
/// list, the sign-in the editor asks for, an invalid step 1 whose blocked
/// Next shows the error, the fix, the comics (a blocked Next there too), the
/// order and review, Create list, and home showing the list id the wiring
/// returned (plan 01 §4.3). Run through `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0048-AC5 home to a new reading list in three steps, and '
      'home shows the id the editor returned', (tester) async {
    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );

    await tester.ensureVisible(find.text('New reading list'));
    await tester.pumpAndSettle();
    await shot(binding, tester, '30_home_new_reading_list');
    await tester.tap(find.text('New reading list'));
    await pumpUntil(tester, _sheetOrStep1, 'the sign-in sheet or step 1');
    // The session is kept on disk: an earlier target on this simulator may
    // have signed in already, and then the editor opens at once.
    if (find.byKey(fixtureSignInSheetKey).evaluate().isNotEmpty) {
      expect(find.textContaining('to save your reading lists'), findsOneWidget);
      await shot(binding, tester, '31_sign_in_sheet');
      await tester.tap(find.byKey(fixtureSignInButtonKey));
      await pumpUntil(tester, find.text('Step 1 of 3'), 'step 1');
    }
    expect(find.byKey(fixtureSignInSheetKey), findsNothing);

    // An invalid step 1: Next is disabled, and a tap on it shows why.
    await tester.tap(find.text('Next'));
    await pumpUntil(
      tester,
      find.text('Give your list a name.'),
      'the error under the name',
    );
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await shot(binding, tester, '32_step1_blocked');

    await tester.enterText(_field('Name'), 'Amber reads');
    await tester.enterText(
      _field('Description (optional)'),
      'Where Amber begins.',
    );
    await tester.tap(find.text('Public'));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Give your list a name.'), findsNothing);
    await shot(binding, tester, '33_step1_details');

    await tester.tap(find.text('Next'));
    await pumpUntil(tester, find.byKey(_result(500060)), 'step 2 results');
    await tester.tap(find.text('Next'));
    await pumpUntil(tester, find.byKey(_comicsError), 'the comics error');
    await tester.tap(find.byKey(_result(500060)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_result(500061)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_result(500062)));
    await pumpUntil(tester, find.text('3 comics picked'), 'three picks');
    await letArtLoad(tester);
    await shot(binding, tester, '34_step2_comics');

    await tester.tap(find.text('Next'));
    await pumpUntil(tester, find.byKey(_review), 'step 3');
    await tester.tap(find.byTooltip('Move Amber Chronicles #3 up'));
    await tester.pumpAndSettle();
    await letArtLoad(tester);
    await shot(binding, tester, '35_step3_review');

    await tester.tap(find.text('Create list'));
    await pumpUntil(
      tester,
      find.text('List created: l-5'),
      'home with the created list',
    );
    expect(find.byKey(_details), findsNothing);
    await shot(binding, tester, '36_home_list_created');
  });
}
