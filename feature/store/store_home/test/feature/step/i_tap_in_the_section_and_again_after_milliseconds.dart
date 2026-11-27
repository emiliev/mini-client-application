import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: I tap {'Amber Frontier #2'} in the {'deals'} section and again after {499} milliseconds
///
/// Two taps [milliseconds] of fake time apart: just inside or just outside
/// the open guard.
Future<void> iTapInTheSectionAndAgainAfterMilliseconds(
  WidgetTester tester,
  String text,
  String section,
  int milliseconds,
) async {
  await letSectionsLand(tester);
  await tapIn(
    tester,
    section,
    find.text(text),
    times: 2,
    between: Duration(milliseconds: milliseconds),
  );
}
