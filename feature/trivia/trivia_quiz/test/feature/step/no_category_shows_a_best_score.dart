import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no category shows a best score
Future<void> noCategoryShowsABestScore(WidgetTester tester) async {
  await tester.pump();
  expect(
    find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('trivia_setup.best.'),
    ),
    findsNothing,
  );
  expect(find.byKey(const ValueKey('trivia_setup.body')), findsOneWidget);
}
