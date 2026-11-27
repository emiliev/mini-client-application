import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the choices carry the marks {'cross'}
///
/// The marks drawn on the revealed choices, as a set: `check` (the player's
/// choice, right), `cross` (the player's choice, wrong), or `{''}` for none
/// (a timeout: the right answer is shown, nothing as the player's).
Future<void> theChoicesCarryTheMarks(WidgetTester tester, String marks) async {
  await tester.pump();
  final shown = {
    if (find
        .byKey(const ValueKey('trivia_play.choice.check'))
        .evaluate()
        .isNotEmpty)
      'check',
    if (find
        .byKey(const ValueKey('trivia_play.choice.cross'))
        .evaluate()
        .isNotEmpty)
      'cross',
  };
  expect(shown, {
    for (final m in marks.split(','))
      if (m.trim().isNotEmpty) m.trim(),
  });
}
