import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I go to the next question
Future<void> iGoToTheNextQuestion(WidgetTester tester) => tapNext(tester);
