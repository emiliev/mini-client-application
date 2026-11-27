import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the description field shows {'Where to begin.'}
Future<void> theDescriptionFieldShows(WidgetTester tester, String text) async =>
    expectFieldText(tester, 'Description (optional)', text);
