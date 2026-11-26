import 'package:comics_details/comics_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I see the cover page of comic {501500}
///
/// The cover is open full size, and it is flow state, not a pushed route:
/// - the flow state holds the comic (read through the flow's controller);
/// - the route is a `Page` the flow generated, named `cover`, with the
///   comic's id as argument, on the flow's navigator rather than the app's;
/// - it draws the bundled asset of the fixture's cover.
Future<void> iSeeTheCoverPageOfComic(WidgetTester tester, int id) async {
  final record = comicRecord(id);
  final image = find.byKey(comicCoverPageImageKey);
  expect(image, findsOneWidget, reason: 'the cover page is open');

  expect(comicsFlowState(tester, image).cover, ComicId(id));

  final page = tester.element(image);
  final route = ModalRoute.of(page)!;
  expect(route.settings, isA<Page<Object?>>(), reason: 'a flow page');
  expect(route.settings.name, 'cover');
  expect(route.settings.arguments, ComicId(id));
  expect(
    Navigator.of(page),
    isNot(same(Navigator.of(page, rootNavigator: true))),
    reason: 'the cover is in the flow, not on the app navigator',
  );
  final art = find.descendant(of: image, matching: find.byType(Image));
  expect(tester.widget<Image>(art).image, bundledArtFor(record.cover));
}
