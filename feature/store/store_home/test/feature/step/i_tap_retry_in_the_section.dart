import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: I tap Retry in the {'deals'} section
///
/// Taps the Retry of that section's own error card.
Future<void> iTapRetryInTheSection(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(retryLabel(tester)));
}
