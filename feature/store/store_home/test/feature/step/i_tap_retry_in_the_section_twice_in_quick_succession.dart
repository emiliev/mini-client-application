import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: I tap Retry in the {'deals'} section twice in quick succession
///
/// Two taps on that section's Retry within one frame: both reach the bloc.
Future<void> iTapRetryInTheSectionTwiceInQuickSuccession(
  WidgetTester tester,
  String section,
) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(retryLabel(tester)), times: 2);
}
