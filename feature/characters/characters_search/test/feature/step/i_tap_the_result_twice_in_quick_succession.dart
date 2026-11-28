import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: I tap the result {'Amber Alchemist'} twice in quick succession
///
/// Two taps on the row within one frame: both reach the row, so both open
/// events reach the bloc.
Future<void> iTapTheResultTwiceInQuickSuccession(
  WidgetTester tester,
  String name,
) => tapResult(tester, name, times: 2);
