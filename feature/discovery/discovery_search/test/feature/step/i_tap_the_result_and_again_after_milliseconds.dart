import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: I tap the result {'Spindle Alchemist'} and again after {499} milliseconds
///
/// Two taps on the row, [milliseconds] of fake time apart.
Future<void> iTapTheResultAndAgainAfterMilliseconds(
  WidgetTester tester,
  String title,
  int milliseconds,
) => tapResult(
  tester,
  title,
  times: 2,
  between: Duration(milliseconds: milliseconds),
);
