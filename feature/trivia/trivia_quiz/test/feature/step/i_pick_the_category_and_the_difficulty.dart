import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I pick the category {'characters'} and the difficulty {'easy'}
Future<void> iPickTheCategoryAndTheDifficulty(
  WidgetTester tester,
  String category,
  String difficulty,
) async {
  for (final key in [
    setupCategoryKey(category),
    setupDifficultyKey(difficulty),
  ]) {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(setupBodyKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.byKey(key));
    await mcSettle(tester);
  }
  pickedOnSetup = (category: category, difficulty: difficulty);
}
