import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

void main() {
  test('T-0029-AC4 DataTable keeps the generated const shape', () {
    const table = DataTable([
      ['name', 'count'],
      ['a', 1],
      ['b', 2],
    ]);
    expect(table.asLists(), hasLength(3));
    expect(table.asMaps(), [
      {'name': 'a', 'count': 1},
      {'name': 'b', 'count': 2},
    ]);
  });

  test('DataTable tolerates an empty table and short rows', () {
    expect(const DataTable([]).asMaps(), isEmpty);
    expect(
      const DataTable([
        ['a', 'b'],
        ['x'],
      ]).asMaps(),
      [
        {'a': 'x', 'b': null},
      ],
    );
  });
}
