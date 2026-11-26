import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the name field shows {'Weekend reads'}
Future<void> theNameFieldShows(WidgetTester tester, String text) async =>
    expectFieldText(tester, 'Name', text);
