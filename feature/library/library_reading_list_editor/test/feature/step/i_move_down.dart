import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I move {'Amber Chronicles #1'} down
Future<void> iMoveDown(WidgetTester tester, String title) =>
    tapTooltip(tester, 'Move $title down');
