import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I move {'Amber Chronicles #3'} up
///
/// Taps the comic's "Move … up" arrow in step 3 (the accessible reorder).
Future<void> iMoveUp(WidgetTester tester, String title) =>
    tapTooltip(tester, 'Move $title up');
