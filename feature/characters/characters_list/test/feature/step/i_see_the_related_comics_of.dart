import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/characters_list_env.dart';

/// Usage: I see the related comics of {'Amber Alchemist'}
///
/// The preview's comics section lists exactly the first five comics the
/// character appears in (from the comics fixture), in title order.
Future<void> iSeeTheRelatedComicsOf(WidgetTester tester, String name) async {
  final section = find.byKey(relatedComicsKey);
  await tester.scrollUntilVisible(
    section,
    200,
    scrollable: previewScrollable().first,
  );
  await tester.pumpAndSettle();
  final titles = [
    for (final element
        in find
            .descendant(of: section, matching: find.byType(ListTile))
            .evaluate())
      ((element.widget as ListTile).title! as Text).data,
  ];
  final expected = [for (final c in relatedComicsOf(name)) c.title];
  expect(expected, isNotEmpty, reason: '$name appears in some comic');
  expect(titles, expected, reason: "$name's comics, in title order");
}
