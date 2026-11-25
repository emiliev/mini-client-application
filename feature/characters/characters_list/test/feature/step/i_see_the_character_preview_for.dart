import 'package:characters_list/characters_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/characters_list_env.dart';

/// Usage: I see the character preview for {'Amber Alchemist'}
///
/// The preview shows [name] and its bundled art, and it is a page of the
/// feature's flow, not an app route: the flow's navigator holds it, under the
/// page name `preview`, with the character's id from the flow state
/// (`previewId`) as its argument.
Future<void> iSeeTheCharacterPreviewFor(
  WidgetTester tester,
  String name,
) async {
  final title = find.byKey(characterPreviewTitleKey);
  expect(title, findsOneWidget, reason: 'the preview is open');
  expect(tester.widget<Text>(title).data, name);

  final record = characterNamed(name);
  final page = tester.element(title);
  final route = ModalRoute.of(page)!;
  expect(route.settings.name, 'preview');
  expect(route.settings.arguments, CharacterId(record.id));
  expect(
    Navigator.of(page),
    isNot(same(Navigator.of(page, rootNavigator: true))),
    reason: 'the preview is in the flow, not on the app navigator',
  );

  final art = find.descendant(
    of: find.ancestor(of: title, matching: find.byType(Scaffold)),
    matching: find.byType(Image),
  );
  expect(tester.widget<Image>(art).image, bundledArtFor(record.thumbnail));
}
