import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I play again
///
/// Taps Play again on the results: a new round of the same category and
/// difficulty with the next seed. Fake time does not move.
Future<void> iPlayAgain(WidgetTester tester) async {
  final spec = currentSpec;
  currentSpec = (
    category: spec.category,
    difficulty: spec.difficulty,
    seed: peekNextSeed(),
  );
  await currentRound(tester);
  final again = find.byKey(resultsPlayAgainKey);
  await tester.scrollUntilVisible(
    again,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(resultsBodyKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(again);
  await landAtOnce(tester);
}
