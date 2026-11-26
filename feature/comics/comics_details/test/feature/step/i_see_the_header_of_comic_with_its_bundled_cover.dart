import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';

import '../util/comics_details_env.dart';

/// Usage: I see the header of comic {501500} with its bundled cover
///
/// The first section shows the fixture comic: its title (in the header and
/// in the app bar) and its cover, drawn from the bundled asset of the
/// fixture's cover path (not the fallback).
Future<void> iSeeTheHeaderOfComicWithItsBundledCover(
  WidgetTester tester,
  int id,
) async {
  final record = comicRecord(id);

  final title = find.byKey(comicTitleKey);
  expect(title, findsOneWidget, reason: 'the header is on screen');
  expect(tester.widget<Text>(title).data, record.title);
  expect(
    tester.widget<McAppBar>(find.byType(McAppBar)).title,
    record.title,
    reason: 'the app bar names the comic',
  );

  final art = find.descendant(
    of: find.byKey(comicCoverKey),
    matching: find.byType(Image),
  );
  expect(art, findsOneWidget, reason: 'the cover is drawn');
  expect(tester.widget<Image>(art).image, bundledArtFor(record.cover));
}
