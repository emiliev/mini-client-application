import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the error {'Give your list a name.'} shows under the name field
Future<void> theErrorShowsUnderTheNameField(
  WidgetTester tester,
  String text,
) async => expectErrorUnder(tester, 'Name', text);
