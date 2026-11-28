import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: I tap the result {'Amber Alchemist'}
///
/// Scrolls the results until the row named [name] is on screen, then taps it
/// once.
Future<void> iTapTheResult(WidgetTester tester, String name) =>
    tapResult(tester, name);
