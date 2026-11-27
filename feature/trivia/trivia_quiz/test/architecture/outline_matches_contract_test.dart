// T-0064-AC6: the scoring Scenario Outline copies the worked examples of
// `mc_fixtures_editorial` CONTRACT.md verbatim. This checks the two tables
// hold the same rows in the same order (the 17 scoring examples and the 5
// hint examples), so neither can change without the other.
import 'dart:io';

import 'package:test/test.dart';

typedef _Row = (
  String id,
  String difficulty,
  String answers,
  int score,
  int correct,
);

/// `| E1 | easy | `C0 W0x9` | 150 | 1 | ...` rows of CONTRACT.md.
List<_Row> contractRows(String contract, String prefix) => [
  for (final m in RegExp(
    '^\\| ($prefix\\d+) \\| (\\w+) \\| `([^`]+)` \\| (\\d+) \\| (\\d+) \\|',
    multiLine: true,
  ).allMatches(contract))
    (m[1]!, m[2]!, m[3]!, int.parse(m[4]!), int.parse(m[5]!)),
];

/// `| 'E1' | 'easy' | 'C0 W0x9' | 150 | 1 |` rows of the feature file.
List<_Row> outlineRows(String feature, String prefix) => [
  for (final m in RegExp(
    "^\\s*\\| '($prefix\\d+)' \\| '(\\w+)' \\| '([^']+)' \\| (\\d+) \\| (\\d+) \\|",
    multiLine: true,
  ).allMatches(feature))
    (m[1]!, m[2]!, m[3]!, int.parse(m[4]!), int.parse(m[5]!)),
];

String _read(String path) => File(path).readAsStringSync();

void main() {
  final contract = _read('utility/mc_fixtures_editorial/CONTRACT.md');
  final feature = _read(
    'feature/trivia/trivia_quiz/test/feature/trivia_quiz_scoring.feature',
  );

  test('T-0064-AC6 the outline holds the 17 scoring examples of CONTRACT.md, '
      'row for row', () {
    final rows = contractRows(contract, 'E');
    expect(rows, hasLength(17));
    expect(outlineRows(feature, 'E'), rows);
  });

  test('T-0064-AC6 the hint outline holds the 5 hint examples, row for '
      'row', () {
    final rows = contractRows(contract, 'H');
    expect(rows, hasLength(5));
    expect(outlineRows(feature, 'H'), rows);
  });

  test('T-0064-AC6 a changed, missing or reordered row is caught (negative '
      'controls)', () {
    final rows = contractRows(contract, 'E');
    expect(
      outlineRows(
        feature.replaceFirst("'C5000 W0x9' | 137", "'C5000 W0x9' | 138"),
        'E',
      ),
      isNot(rows),
    );
    expect(
      outlineRows(
        feature.replaceFirst(RegExp(r"^\s*\| 'E9' .*\n", multiLine: true), ''),
        'E',
      ),
      isNot(rows),
    );
    expect(outlineRows(feature, 'E').reversed.toList(), isNot(rows));
  });
}
