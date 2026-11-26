import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: {'collector@mini-client.test'} has {1} reading lists
///
/// How many lists the backend holds for that user (read directly).
Future<void> hasReadingLists(
  WidgetTester tester,
  String email,
  int count,
) async {
  final response = await libraryProbe(tester, email, 'GET', '/v1/me/lists');
  expect(response.statusCode, 200);
  expect(
    (response.data! as Map)['lists']! as List<Object?>,
    hasLength(count),
    reason: "$email's lists",
  );
}
