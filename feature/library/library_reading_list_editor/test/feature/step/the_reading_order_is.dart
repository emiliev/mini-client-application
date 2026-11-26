import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the reading order is
///   | 'title'               |
///   | 'Amber Chronicles #1' |
///
/// Step 3's rows, top to bottom (each row's "Move … up" arrow names it).
Future<void> theReadingOrderIs(WidgetTester tester, DataTable table) async =>
    expect(readingOrder(tester), titlesOf(table), reason: 'the reading order');
