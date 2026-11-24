/// A Gherkin data table, as the BDD generator passes it to a step.
///
/// The generated code calls `const bdd.DataTable([[...], ...])` with the
/// header row first, the same shape as `package:bdd_widget_test/data_table.dart`,
/// so tests never depend on `bdd_widget_test` at run time (plan 03 X2).
final class DataTable {
  const DataTable(this._rows);

  final List<List<Object?>> _rows;

  /// Every row, the header row included.
  List<List<Object?>> asLists() => _rows;

  /// One map per data row, keyed by the header row.
  List<Map<Object?, Object?>> asMaps() {
    if (_rows.isEmpty) {
      return const [];
    }
    final headers = _rows.first;
    return [
      for (final row in _rows.skip(1))
        {
          for (var i = 0; i < headers.length; i++)
            headers[i]: i < row.length ? row[i] : null,
        },
    ];
  }
}
