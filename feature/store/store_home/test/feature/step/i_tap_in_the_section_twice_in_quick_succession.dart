import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: I tap {'Amber Frontier #2'} in the {'deals'} section twice in quick succession
///
/// Two taps within one frame: both reach the widget, so both events reach
/// its bloc.
Future<void> iTapInTheSectionTwiceInQuickSuccession(
  WidgetTester tester,
  String text,
  String section,
) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(text), times: 2);
}
