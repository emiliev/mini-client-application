import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _comicTitle = ValueKey<String>('comics_details.title');
const _comicBody = ValueKey<String>('comics_details.body');
const _cast = ValueKey<String>('comics_details.cast');
const _signInForm = ValueKey<String>('auth_signin.form');
const _demoReader = ValueKey<String>(
  'auth_signin.demo.reader@mini-client.test',
);

/// The scrollable of the comic page.
Finder _comicScrollable() => find
    .descendant(of: find.byKey(_comicBody), matching: find.byType(Scrollable))
    .first;

/// T-0041-AC5 on a simulator, through the real `main()`: home, Characters,
/// the first character's preview, a related comic, and the comic page; then
/// the favourite through the sign-in form (AC6 in the
/// app), and the cast's way out to the characters placeholder (AC3 in the
/// app). Run through `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0041-AC5 home to a character preview, a related comic and '
      'its page; favourite after sign-in; the cast leads on', (tester) async {
    // Fixture facts (seed 42): the first character, its first comic in title
    // order, and that comic's first cast member.
    final characters = CharacterUniverse(42, defaultMockClock).byName;
    final first = characters.first;
    final comic = ComicUniverse(42).comicsOfCharacter(first.id).first;
    final castName = characters
        .firstWhere((c) => c.id == comic.characterIds.first)
        .name;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    await shot(binding, tester, '10_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first character card');
    await letArtLoad(tester);
    await shot(binding, tester, '11_characters_list');

    await tester.tap(find.text(first.name));
    await pumpUntil(tester, find.text('Comics'), 'the related comics section');
    await tester.scrollUntilVisible(
      find.text(comic.title),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await shot(binding, tester, '12_preview_related_comics');

    await tester.tap(find.text(comic.title));
    await pumpUntil(tester, find.byKey(_comicTitle), 'the comic page');
    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, comic.title);
    expect(find.text('Issue #${comic.issueNumber}'), findsOneWidget);
    await letArtLoad(tester);
    await shot(binding, tester, '13_comic_page');

    await tester.tap(find.text('Add to favourites'));
    await pumpUntil(tester, find.byKey(_signInForm), 'the sign-in form');
    expect(find.text('Sign in to keep your favourites.'), findsOneWidget);
    await shot(binding, tester, '14_sign_in_form');

    await tester.tap(find.byKey(_demoReader));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(McFormScaffold.submitKey));
    await pumpUntil(
      tester,
      find.text('Remove from favourites'),
      'the saved favourite',
    );
    expect(find.byKey(_signInForm), findsNothing);
    await shot(binding, tester, '15_favourite_saved');

    await tester.scrollUntilVisible(
      find.byKey(_cast),
      200,
      scrollable: _comicScrollable(),
    );
    await tester.ensureVisible(find.text(castName));
    await tester.pump(const Duration(milliseconds: 600));
    await letArtLoad(tester, const Duration(seconds: 2));
    await shot(binding, tester, '16_comic_cast');

    await tester.tap(find.text(castName));
    await pumpUntil(
      tester,
      find.byKey(const Key('character.details.placeholder')),
      'the character details placeholder',
    );
    expect(
      find.text('Character details ${comic.characterIds.first}'),
      findsOneWidget,
    );
    await shot(binding, tester, '17_cast_member_placeholder');
  });
}
