import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _field = ValueKey<String>('characters_search.field');
const _results = ValueKey<String>('characters_search.results');

/// The field's text.
String _fieldText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(_field),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

/// T-0071-AC5's deep link: `miniclient://app/characters/search?q=a` opens
/// the search with "a" in the field and its results, through the file-drop
/// start link (F-0020: `simctl openurl` shows a prompt no script can
/// answer), with the characters list and home below it. Then a link sent to
/// the running app (as iOS delivers it) opens a search for another query.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0071-AC5 the deep link miniclient://app/characters/search?q=a '
      'opens the search with its results, over the list and home', (
    tester,
  ) async {
    final cast = CharacterUniverse(42, defaultMockClock).byName;
    final first = cast.firstWhere((c) => c.name.toLowerCase().startsWith('a'));
    final spi = cast.firstWhere((c) => c.name.toLowerCase().startsWith('spi'));
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/characters/search?q=a',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(first.name),
      ),
      'the linked search results',
    );
    expect(_fieldText(tester), 'a');
    expect(
      find.byKey(const Key('home.placeholder')),
      findsNothing,
      reason: 'the link, not home, was the start location',
    );
    await letArtLoad(tester);
    await shot(binding, tester, '97_deep_link_characters_search');

    // Back: the characters list, then home.
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(charactersGridKey),
      'the characters list, after Back from the cold link',
    );
    await shot(binding, tester, '98_back_from_search_is_list');
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'home, after Back from the list',
    );

    // A link to the running app stacks another search.
    await pushLink(tester, 'miniclient://app/characters/search?q=spi');
    await pumpUntil(
      tester,
      find
          .descendant(
            of: find.byKey(_results),
            matching: find.text(spi.name),
          )
          .hitTestable(),
      'the second linked search',
    );
    expect(_fieldText(tester), 'spi');
    await letArtLoad(tester);
    await shot(binding, tester, '99_link_to_running_app_characters_search');
  });
}
