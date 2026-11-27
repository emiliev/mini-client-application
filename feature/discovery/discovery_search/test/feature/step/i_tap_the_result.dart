import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: I tap the result {'Spindle Chronicles #1'}
///
/// Scrolls the results until the row titled [title] is on screen, then taps
/// it once.
Future<void> iTapTheResult(WidgetTester tester, String title) =>
    tapResult(tester, title);
