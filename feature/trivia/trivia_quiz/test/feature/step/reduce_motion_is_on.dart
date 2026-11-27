import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: reduce motion is on
///
/// The test host sets `MediaQuery.disableAnimations`, as iOS's Reduce
/// Motion does. Set it before the step that opens the flow.
Future<void> reduceMotionIsOn(WidgetTester tester) async => reduceMotion = true;
