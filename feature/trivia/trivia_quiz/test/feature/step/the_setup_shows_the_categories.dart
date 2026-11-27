import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the setup shows the categories {'All categories, Characters, Comics, Creators'}
///
/// These category names, top to bottom.
Future<void> theSetupShowsTheCategories(
  WidgetTester tester,
  String names,
) async {
  await tester.pump();
  final expected = [for (final n in names.split(',')) n.trim()];
  final shown = [
    for (final n in expected)
      (
        name: n,
        y: tester
            .getTopLeft(
              find.descendant(
                of: find.byKey(setupBodyKey),
                matching: find.text(n),
              ),
            )
            .dy,
      ),
  ]..sort((a, b) => a.y.compareTo(b.y));
  expect([for (final s in shown) s.name], expected);
}
