import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I start the round
///
/// Taps Start on the setup: the round of the picked category and difficulty
/// with the next seed opens above the setup. Fake time does not move, so
/// the first question's clock starts at 0; the page is still sliding in, so
/// the first answer must come after its transition (500 ms or more).
Future<void> iStartTheRound(WidgetTester tester) async {
  final picked = pickedOnSetup;
  currentSpec = (
    category: picked.category,
    difficulty: picked.difficulty,
    seed: peekNextSeed(),
  );
  await currentRound(tester);
  await tester.scrollUntilVisible(
    find.byKey(setupStartKey),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(setupBodyKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  await tester.tap(find.byKey(setupStartKey));
  await landAtOnce(tester);
}
