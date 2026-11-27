import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the {'deals'} section shows {'No deals right now.'}
///
/// [text] is inside that section (non-breaking spaces read as plain ones).
Future<void> theSectionShows(
  WidgetTester tester,
  String section,
  String text,
) async {
  await letSectionsLand(tester);
  await scrollToSection(tester, section);
  final match = find.descendant(
    of: find.byKey(sectionKey(section)),
    matching: find.byWidgetPredicate(
      (w) => w is Text && plainSpaces(w.data ?? '') == plainSpaces(text),
    ),
  );
  if (match.evaluate().isEmpty) {
    await scrollStoreUntilVisible(tester, match);
  }
  expect(match, findsWidgets, reason: 'the $section section shows "$text"');
}
