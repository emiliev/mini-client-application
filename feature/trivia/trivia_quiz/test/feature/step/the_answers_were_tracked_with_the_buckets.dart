import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the answers were tracked with the buckets {'q1 q4 timeout'}
///
/// One `trivia_answer` per question, in order, with these `elapsed_bucket`s
/// (`correct` is true exactly when the bucket is not `timeout` and the
/// answer was right; that is checked by the scenario's other steps).
Future<void> theAnswersWereTrackedWithTheBuckets(
  WidgetTester tester,
  String buckets,
) async {
  final answers = McTestSession.current.analytics.events
      .where((e) => e.name == 'trivia_answer')
      .toList();
  expect(
    [for (final e in answers) e.params['elapsed_bucket']],
    [
      for (final b in buckets.split(' ')) b,
    ],
  );
  for (final e in answers) {
    expect(e.params.keys.toSet(), {'correct', 'elapsed_bucket'});
    if (e.params['elapsed_bucket'] == 'timeout') {
      expect(e.params['correct'], isFalse);
    }
  }
}
