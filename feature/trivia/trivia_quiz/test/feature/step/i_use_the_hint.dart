import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I use the hint
Future<void> iUseTheHint(WidgetTester tester) async {
  await tester.tap(find.byKey(playHintKey));
  await tester.pump();
}
