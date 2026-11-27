import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I enter {'Amber reads'} in the field {'[Ñàɱé ~~]'}
///
/// Like `I enter ... as the name`, for a field found by its label in any
/// locale.
Future<void> iEnterInTheField(WidgetTester tester, String text, String label) =>
    enterText(tester, label, text);
