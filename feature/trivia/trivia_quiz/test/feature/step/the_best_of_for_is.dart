import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the best of {'reader@mini-client.test'} for {'all'} is {870}
///
/// Read on the backend with a minted token.
Future<void> theBestOfForIs(
  WidgetTester tester,
  String email,
  String category,
  int best,
) async {
  expect((await backendBest(tester, email))[category], best);
}
