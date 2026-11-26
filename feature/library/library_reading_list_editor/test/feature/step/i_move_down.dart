import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I move {'Amber Chronicles #1'} down
Future<void> iMoveDown(WidgetTester tester, String title) =>
    tapTooltip(tester, 'Move $title down');
