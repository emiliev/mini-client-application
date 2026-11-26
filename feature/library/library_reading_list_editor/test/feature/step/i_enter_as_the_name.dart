import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I enter {'Weekend reads'} as the name
///
/// Replaces the name field's text, as typing does, then leaves the field
/// (its error may show once it lost focus).
Future<void> iEnterAsTheName(WidgetTester tester, String text) =>
    enterText(tester, 'Name', text);
