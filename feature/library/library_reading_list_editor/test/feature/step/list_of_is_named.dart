import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: list {'l-5'} of {'reader@mini-client.test'} is named {'Weekend reads'}
Future<void> listOfIsNamed(
  WidgetTester tester,
  String id,
  String email,
  String name,
) async {
  final list = await storedList(tester, email, id);
  expect(list['name'], name, reason: 'the stored name of $id');
}
