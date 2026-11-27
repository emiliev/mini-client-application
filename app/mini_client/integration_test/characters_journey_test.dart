import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _profileName = ValueKey<String>('characters_details.name');
const _profileBody = ValueKey<String>('characters_details.body');
const _profileComics = ValueKey<String>('characters_details.comics');
const _comicTitle = ValueKey<String>('comics_details.title');

/// T-0033-AC4 and T-0067-AC5 on a simulator, through the real `main()`: the production
/// boot, router, wiring, backend and bundled art. Run through
/// `tool/e2e_ios.sh` (see tool/e2e/README in the T-0033 task).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0067-AC5 home to the characters list, a preview, the full '
      'profile, a comic, Back, Back', (tester) async {
    // The first character of `characters.default` (seed 42), by the fixture
    // package's own facts.
    final first = CharacterUniverse(42, defaultMockClock).byName.first;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    expect(find.text('Characters'), findsOneWidget);
    await shot(binding, tester, '01_home');

    await tester.tap(find.text('Characters'));
    await pumpUntil(tester, find.text(first.name), 'the first character card');
    expect(find.byKey(charactersGridKey), findsOneWidget);
    expect(find.byType(Image), findsWidgets, reason: 'bundled art shows');
    await letArtLoad(tester);
    await shot(binding, tester, '02_characters_list');

    await tester.tap(find.text(first.name));
    await pumpUntil(
      tester,
      find.text('See full profile'),
      'the preview with its profile button',
    );
    expect(find.byKey(characterPreviewTitleKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(characterPreviewTitleKey)).data,
      first.name,
    );
    await shot(binding, tester, '03_preview');

    await tester.tap(find.text('See full profile'));
    await pumpUntil(tester, find.byKey(_profileName), 'the character profile');
    expect(tester.widget<Text>(find.byKey(_profileName)).data, first.name);
    await letArtLoad(tester);
    await shot(binding, tester, '04_profile_top');

    // The comics row sits below the fold: scroll to it, then open the first.
    final comic = ComicUniverse(42).comicsOfCharacter(first.id).first;
    await tester.scrollUntilVisible(
      find.byKey(_profileComics),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(_profileBody),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await letArtLoad(tester);
    await shot(binding, tester, '05_profile_comics');

    await tester.tap(find.text(comic.title));
    await pumpUntil(tester, find.byKey(_comicTitle), 'the comic page');
    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, comic.title);
    await letArtLoad(tester);
    await shot(binding, tester, '06_comic_page');

    // Back: the profile, still scrolled to its comics row (the header above
    // it is not built).
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(_profileComics),
      'the profile again, still on its comics row',
    );
    expect(find.byKey(_comicTitle), findsNothing);
    await shot(binding, tester, '07_back_to_profile');

    // Back: the preview the profile was opened from.
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.text('See full profile'),
      'the preview, below the profile',
    );
    expect(find.byKey(_profileComics), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(characterPreviewTitleKey)).data,
      first.name,
    );
    await shot(binding, tester, '08_back_to_preview');
  });
}
