import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/data_table.dart';

/// Usage: I see the texts
///   | 'text'    |
///   | 'Hero 01' |
///
/// Every row's `text` cell is on screen.
Future<void> iSeeTheTexts(WidgetTester tester, DataTable table) async {
  final rows = table.asMaps();
  expect(rows, isNotEmpty, reason: 'the table lists no texts');
  for (final row in rows) {
    final text = row['text'];
    expect(text, isA<String>(), reason: 'every row needs a text cell');
    expect(
      find.text(text! as String),
      findsWidgets,
      reason: 'expected "$text"',
    );
  }
}
