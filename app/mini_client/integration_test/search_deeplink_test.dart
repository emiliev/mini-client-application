import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _field = ValueKey<String>('discovery_search.field');
const _results = ValueKey<String>('discovery_search.results');

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

/// T-0046-AC5's deep link: `miniclient://app/search?q=spi` opens the search
/// with "spi" in the field and its results, through the file-drop start link
/// (F-0020: `simctl openurl` shows a prompt no script can answer). Then a
/// link sent to the running app (as iOS delivers it) opens a search for
/// another query over the first.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0046-AC5 the deep link miniclient://app/search?q=spi opens '
      'the search with its results', (tester) async {
    final index = SearchIndex.fromUniverses(42, defaultMockClock);
    String first(String query) =>
        index.search(query, types: ['character']).first.entry.title;
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/search?q=spi',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(first('spi')),
      ),
      'the linked search results',
    );
    expect(_fieldText(tester), 'spi');
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
    await shot(binding, tester, '36_deep_link_search');
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'T-0049-AC1: home, after Back from the cold link',
    );
    await shot(binding, tester, '36b_back_from_search_is_home');
    // A link to the running app stacks [home, search] again.
    await pushLink(tester, 'miniclient://app/search?q=spi');
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(first('spi')),
      ),
      'the search again, after Back',
    );

    await pushLink(tester, 'miniclient://app/search?q=amber');
    await pumpUntil(
      tester,
      find
          .descendant(
            of: find.byKey(_results),
            matching: find.text(first('amber')),
          )
          .hitTestable(),
      'the second linked search',
    );
    expect(_fieldText(tester), 'amber');
    await letArtLoad(tester);
    await shot(binding, tester, '37_link_to_running_app_search');
  });
}
