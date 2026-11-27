import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';

import '../util/characters_details_env.dart';

/// Usage: I see the header of character {100002} with its bundled portrait
///
/// The first section shows the fixture character: its name (in the header
/// and in the app bar), its aliases as "Also known as ..." (nothing when it
/// has none) and its portrait, drawn from the bundled asset of the fixture's
/// thumbnail path (not the fallback).
Future<void> iSeeTheHeaderOfCharacterWithItsBundledPortrait(
  WidgetTester tester,
  int id,
) async {
  final record = characterWithId(id);

  final name = find.byKey(characterNameKey);
  expect(name, findsOneWidget, reason: 'the header is on screen');
  expect(tester.widget<Text>(name).data, record.name);
  expect(
    tester.widget<McAppBar>(find.byType(McAppBar)).title,
    record.name,
    reason: 'the app bar names the character',
  );

  final aliases = find.byKey(characterAliasesKey);
  if (record.aliases.isEmpty) {
    expect(aliases, findsNothing, reason: '${record.name} has no aliases');
  } else {
    expect(
      tester.widget<Text>(aliases).data,
      'Also known as ${record.aliases.join(', ')}',
    );
  }

  final art = find.descendant(
    of: find.byKey(characterPortraitKey),
    matching: find.byType(Image),
  );
  expect(art, findsOneWidget, reason: 'the portrait is drawn');
  expect(tester.widget<Image>(art).image, bundledArtFor(record.thumbnail));
}
