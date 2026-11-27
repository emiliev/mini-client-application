import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the points per question are {'150 0 0 0 0 0 0 0 0 0'}
///
/// The values the results' bar chart draws, in question order.
Future<void> thePointsPerQuestionAre(WidgetTester tester, String points) async {
  await tester.pump();
  final chart = tester.widget<McBarChart>(
    find.byKey(breakdownBarsKey, skipOffstage: false),
  );
  expect(
    [for (final b in chart.data) b.value.toInt()],
    [
      for (final p in points.split(' ')) int.parse(p),
    ],
  );
}
