import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: the stats chart reads {'Power stats of Spiral Warden', 'Intelligence: 72, Strength: 93'}
///
/// What a screen reader gets from the chart, in VoiceOver order: its summary
/// label, then one node per bar. [summary] is the node that starts the chart;
/// [bars] are the nodes that follow it immediately, comma separated, in order.
Future<void> theStatsChartReadsThen(
  WidgetTester tester,
  String summary,
  String bars,
) async {
  final handle = tester.ensureSemantics();
  final List<String> labels;
  try {
    await scrollCharacterUntilVisible(tester, find.byKey(characterStatsKey));
    labels = [
      for (final node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.label.isNotEmpty) node.label,
    ];
  } finally {
    handle.dispose();
  }
  final expected = [for (final bar in bars.split(', ')) bar];
  final start = labels.indexOf(summary);
  expect(start, isNot(-1), reason: 'the chart summary "$summary" is read');
  expect(
    labels.sublist(start + 1, start + 1 + expected.length),
    expected,
    reason: 'the bars read after the summary, in order',
  );
}
