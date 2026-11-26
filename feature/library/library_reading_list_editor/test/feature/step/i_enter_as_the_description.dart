import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I enter {'Where to begin.'} as the description
Future<void> iEnterAsTheDescription(WidgetTester tester, String text) =>
    enterText(tester, 'Description (optional)', text);
