import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the error {'Give your list a name.'} shows under the field {'Name'}
///
/// The text field labelled [label] shows [text] as its error (the
/// `McTextField`'s error slot, announced as a live region).
Future<void> theErrorShowsUnderTheField(
  WidgetTester tester,
  String text,
  String label,
) async => expectErrorUnder(tester, label, text);
