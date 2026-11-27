import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the category {'characters'} shows the best {1340}
Future<void> theCategoryShowsTheBest(
  WidgetTester tester,
  String category,
  int best,
) async {
  await tester.pump();
  expect(textOf(tester, setupBestKey(category)), 'Best $best');
}
