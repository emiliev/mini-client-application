import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: I tap the result {'Amber Alchemist'} and again after {499} milliseconds
///
/// Two taps on the row, [milliseconds] of fake time apart.
Future<void> iTapTheResultAndAgainAfterMilliseconds(
  WidgetTester tester,
  String name,
  int milliseconds,
) => tapResult(
  tester,
  name,
  times: 2,
  between: Duration(milliseconds: milliseconds),
);
