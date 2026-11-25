import 'dart:convert';
import 'dart:io';

import 'package:l10n_check/l10n_check.dart';
import 'package:test/test.dart';

/// The gate: every ARB set in the workspace (the `arbs` filegroups listed in
/// this package's BUILD.bazel `workspace_gate_test` data) is complete.
void main() {
  test('T-0025-AC3 the workspace ARB sets are complete (gate)', () {
    final root = Directory.current.path;
    final arbs = Directory(root)
        .listSync(recursive: true, followLinks: false)
        .where((e) => e.path.endsWith('.arb'))
        .toList();
    expect(arbs, isNotEmpty, reason: 'no ARB files in runfiles at $root');
    expect(checkL10n(root), isEmpty);
  });

  test('T-0032-AC4 the gate checks the characters_list ARB set', () {
    const dir = 'feature/characters/characters_list/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/characters_list_$locale.arb').existsSync(),
        isTrue,
        reason: 'characters_list_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/characters_list_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('charactersListTitle');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('characters_list'),
          contains('de'),
          contains('charactersListTitle'),
        ),
      ),
    );
  });
}
