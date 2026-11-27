import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';
import 'the_section_shows_its_error_with_retry.dart';

/// Usage: every section but {'deals'} shows its error
Future<void> everySectionButShowsItsError(
  WidgetTester tester,
  String section,
) async {
  for (final other in storeSections.where((s) => s != section)) {
    await theSectionShowsItsErrorWithRetry(tester, other);
  }
}
