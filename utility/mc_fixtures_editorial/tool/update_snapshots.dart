// Rewrites the provider contract snapshots from the current handlers.
//
//   fvm dart run utility/mc_fixtures_editorial/tool/update_snapshots.dart
import 'dart:convert';
import 'dart:io';

import '../test/contract/snapshot_cases.dart';

Future<void> main() async {
  final dir = Directory('utility/mc_fixtures_editorial/test/contract/snapshots')
    ..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final entry in snapshotCases.entries) {
    final snapshot = await runSnapshotCase(entry.value);
    File(
      '${dir.path}/${entry.key}.json',
    ).writeAsStringSync('${encoder.convert(_sorted(snapshot))}\n');
  }
  stdout.writeln('Wrote ${snapshotCases.length} snapshots to ${dir.path}');
}

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sorted(value[k])};
  }
  if (value is List) {
    return [for (final v in value) _sorted(v)];
  }
  return value;
}
