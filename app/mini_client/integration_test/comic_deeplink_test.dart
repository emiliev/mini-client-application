import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mini_client/main.dart' as app;

const _comicTitle = ValueKey<String>('comics_details.title');

/// T-0041-AC5's deep link: `miniclient://app/comics/501500` opens the comic
/// page through the file-drop start link (F-0020: `simctl openurl` shows a
/// prompt no script can answer). `main()` reads and deletes the file, then
/// the link takes the same PendingLinks -> GoRouter path as a cold-start
/// link. Then a link sent to the running app (as iOS delivers it) opens a
/// second comic over the first, and a link with a non-numeric id shows the
/// app's not-found page.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0041-AC5 the deep link miniclient://app/comics/501500 opens '
      'the comic page', (tester) async {
    final comics = ComicUniverse(42);
    final linked = comics.findComic(501500)!;
    final second = comics.findComic(500000)!;
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/comics/501500',
    );

    startApp(app.main);
    await pumpUntil(tester, find.byKey(_comicTitle), 'the linked comic page');

    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, linked.title);
    expect(
      find.byKey(const Key('home.placeholder')),
      findsNothing,
      reason: 'the link, not home, was the start location',
    );
    await letArtLoad(tester);
    expect(
      find.byType(BackButton),
      findsWidgets,
      reason: 'T-0049-AC1: the cold link has a back button',
    );
    await shot(binding, tester, '18_deep_link_comic');
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'T-0049-AC1: home, after Back from the cold link',
    );
    await shot(binding, tester, '18b_back_from_comic_is_home');

    await pushLink(tester, 'miniclient://app/comics/500000');
    await pumpUntil(
      tester,
      find.text(second.title).hitTestable(),
      'the second linked comic',
    );
    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, second.title);
    await letArtLoad(tester);
    await shot(binding, tester, '19_link_to_running_app_comic');

    // A comic id that is not a number: the app's not-found page, not a crash.
    await pushLink(tester, 'miniclient://app/comics/abc');
    await pumpUntil(
      tester,
      find.byKey(const Key('not.found')),
      'the not-found page for a non-numeric comic id',
    );
    expect(find.textContaining('comics/abc'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    await shot(binding, tester, '20_bad_comic_link_not_found');
  });
}
