import 'package:characters_list/characters_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/characters_list_env.dart';

/// Usage: I see the character preview for {'Amber Alchemist'}
///
/// The preview shows [name] and its bundled art, and it is flow state, not a
/// pushed route:
/// - the flow state selects [name] (read through the flow's controller);
/// - the route is a `Page` the flow generated (a pushed route has plain
///   `RouteSettings`), named `preview`, with the character's id as argument,
///   on the flow's navigator rather than the app's;
/// - the page is keyed by that id, so another selection gets a new page.
Future<void> iSeeTheCharacterPreviewFor(
  WidgetTester tester,
  String name,
) async {
  final record = characterNamed(name);
  final id = CharacterId(record.id);

  final selected = charactersFlowState(tester).preview;
  expect(selected?.id, id, reason: 'the flow state selects $name');
  expect(selected?.name, name);

  final title = find.byKey(characterPreviewTitleKey);
  expect(title, findsOneWidget, reason: 'the preview is open');
  expect(tester.widget<Text>(title).data, name);

  final page = tester.element(title);
  final route = ModalRoute.of(page)!;
  expect(
    route.settings,
    isA<Page<Object?>>(),
    reason: 'a flow page, not a pushed route',
  );
  expect(route.settings.name, 'preview');
  expect(route.settings.arguments, id);
  expect(
    Navigator.of(page),
    isNot(same(Navigator.of(page, rootNavigator: true))),
    reason: 'the preview is in the flow, not on the app navigator',
  );
  expect(
    find.byKey(ValueKey(id)),
    findsOneWidget,
    reason: 'the preview page is keyed by the selected id',
  );

  // The character's own art in this preview's Scaffold (the related comics
  // below it show covers of their own, T-0041).
  final art = find.descendant(
    of: find.descendant(
      of: find.ancestor(of: title, matching: find.byType(Scaffold)),
      matching: find.byKey(characterPreviewArtKey),
    ),
    matching: find.byType(Image),
  );
  expect(tester.widget<Image>(art).image, bundledArtFor(record.thumbnail));
}
