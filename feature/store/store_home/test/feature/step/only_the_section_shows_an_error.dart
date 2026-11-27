import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';
import 'the_section_is_ready.dart';
import 'the_section_shows_its_error_with_retry.dart';

/// Usage: only the {'deals'} section shows an error
///
/// That section shows its own error card with Retry, and every other
/// section of the store is ready (P1-21 AC6).
Future<void> onlyTheSectionShowsAnError(
  WidgetTester tester,
  String section,
) async {
  await theSectionShowsItsErrorWithRetry(tester, section);
  for (final other in storeSections.where((s) => s != section)) {
    await theSectionIsReady(tester, other);
  }
}
