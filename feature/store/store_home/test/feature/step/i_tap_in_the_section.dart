import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: I tap {'Amber Frontier #2'} in the {'deals'} section
///
/// Scrolls to the item inside that section (a carousel is scrolled
/// sideways) and taps it.
Future<void> iTapInTheSection(
  WidgetTester tester,
  String text,
  String section,
) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(text));
}
