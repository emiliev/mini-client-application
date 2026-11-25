// Conformance of the package's shape (plan 01 §3.3), not a test of feature
// behaviour: R4 (the barrel) and R15 (generators read Flutter-free files).
import 'dart:io';

import 'package:test/test.dart';

/// `dart test` runs in the package; Bazel runs at the runfiles root.
String _path(String rel) {
  const pkg = 'feature/characters/characters_list';
  return File('$pkg/$rel').existsSync() ? '$pkg/$rel' : rel;
}

final RegExp _export = RegExp(
  r'''export\s+'([^']+)'\s*(show\s+([^;]+))?;''',
  multiLine: true,
);

void main() {
  test('T-0032-AC6 the barrel exports only the flow, the navigator and its '
      'argument type, each with show', () {
    final barrel = File(_path('lib/characters_list.dart')).readAsStringSync();
    final exports = _export.allMatches(barrel).toList();

    expect(exports, isNotEmpty);
    final shown = <String>{};
    for (final e in exports) {
      expect(
        e.group(2),
        isNotNull,
        reason: '${e.group(1)} exports without show',
      );
      shown.addAll(e.group(3)!.split(',').map((s) => s.trim()));
      expect(e.group(1), startsWith('package:characters_list/src/'));
    }
    expect(shown, {
      'CharactersListFlow',
      'CharactersListNavigator',
      'CharacterId',
    });
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('T-0032-AC6 every file a generator reads imports no Flutter (R15)', () {
    final list = File(_path('test/architecture/pure_srcs.txt'));
    final files = list
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    expect(files, hasLength(greaterThan(10)));
    final flutter = RegExp(
      r'''(import|export)\s+'(package:flutter|dart:ui)''',
    );
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });
}
