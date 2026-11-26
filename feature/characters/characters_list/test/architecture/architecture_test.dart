// Conformance of the package's shape (plan 01 §3.3), not a test of feature
// behaviour: R4 (the barrel) and R15 (generators read Flutter-free files).
import 'dart:io';

import 'package:test/test.dart';

/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => 'feature/characters/characters_list/$rel';

/// One export directive, in either quote style, with an optional `show`.
final RegExp _export = RegExp(
  r'''export\s+(['"])([^'"]+)\1\s*(show\s+([^;]+))?;''',
  multiLine: true,
);

/// Any export directive at all, to check [_export] understood each one.
final RegExp _anyExport = RegExp(r'^\s*export\b', multiLine: true);

/// A Flutter import or export, in either quote style.
final RegExp _flutter = RegExp(
  r'''(import|export)\s+['"](package:flutter[a-z_]*/|dart:ui)''',
);

void main() {
  test('T-0032-AC6 the barrel exports only the flow, the navigator and its '
      'argument type, each with show', () {
    final barrel = File(_path('lib/characters_list.dart')).readAsStringSync();
    final exports = _export.allMatches(barrel).toList();

    expect(exports, isNotEmpty);
    expect(
      exports,
      hasLength(_anyExport.allMatches(barrel).length),
      reason: 'every export directive is one this check understands',
    );
    final shown = <String>{};
    for (final e in exports) {
      expect(
        e.group(3),
        isNotNull,
        reason: '${e.group(2)} exports without show',
      );
      shown.addAll(e.group(4)!.split(',').map((s) => s.trim()));
      expect(e.group(2), startsWith('package:characters_list/src/'));
    }
    expect(shown, {
      'CharactersListFlow',
      'CharactersListNavigator',
      'CharacterId',
      // T-0041: openComic's argument.
      'ComicId',
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
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

  test('T-0032-AC6 the checks read both quote styles', () {
    expect(_flutter.hasMatch('import "package:flutter/widgets.dart";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter/widgets.dart';"), isTrue);
    expect(_flutter.hasMatch('export "dart:ui";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter_bloc/x.dart';"), isTrue);
    expect(_flutter.hasMatch("import 'package:freezed/x.dart';"), isFalse);

    final e = _export.firstMatch('export "package:x/src/a.dart" show A, B;')!;
    expect(e.group(2), 'package:x/src/a.dart');
    expect(e.group(4), 'A, B');
    expect(_export.hasMatch('export "package:x/a.dart\';'), isFalse);
  });
}
