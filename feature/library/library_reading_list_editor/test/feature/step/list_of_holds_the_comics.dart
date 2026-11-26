import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: list {'l-5'} of {'reader@mini-client.test'} holds the comics
///   | 'title'               |
///   | 'Amber Chronicles #1' |
///
/// What the backend stores for that user's list (read directly, not through
/// the app), in order.
Future<void> listOfHoldsTheComics(
  WidgetTester tester,
  String id,
  String email,
  DataTable table,
) async {
  final list = await storedList(tester, email, id);
  expect(
    [for (final item in list['items']! as List<Object?>) (item! as Map)['title']],
    titlesOf(table),
    reason: 'the comics of $id',
  );
}
