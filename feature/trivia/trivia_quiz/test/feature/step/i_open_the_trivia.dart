import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I open the trivia
///
/// Enters the feature the way the app does at `/trivia`: through its flow
/// (barrel only), with the navigator, the clock and the seeds passed in.
Future<void> iOpenTheTrivia(WidgetTester tester) async {
  await ensureTriviaContainer();
  await initFlow(tester, () => triviaTestHost(triviaFlowUnderTest()));
  await mcSettle(tester);
}
