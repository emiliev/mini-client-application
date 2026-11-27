// Conformance of the package's shape (plan 01 §3.3), not a test of feature
// behaviour: R4 (the barrel), R15 (generators read Flutter-free files), and
// money never in floating point.
import 'dart:io';

import 'package:test/test.dart';

/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => 'feature/store/store_home/$rel';

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

/// What floating-point money would need: a `double` or `num`, a conversion
/// to one, or a rounding call. Comments are stripped first.
final RegExp _floatingPoint = RegExp(
  r'\bdouble\b|\bnum\b|\.toDouble\(|\.round\(|\.floor\(|\.ceil\(|\.truncate\(',
);

String _code(String source) => source
    .replaceAll(RegExp(r'//.*'), '')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

List<String> _pureSrcs() =>
    File(_path('test/architecture/pure_srcs.txt'))
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

void main() {
  test('T-0056-AC8 the barrel exports only the flow, the navigator and their '
      'argument types, each with show', () {
    final barrel = File(_path('lib/store_home.dart')).readAsStringSync();
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
      expect(e.group(2), startsWith('package:store_home/src/'));
    }
    expect(shown, {
      'StoreHomeFlow',
      'StoreHomeNavigator',
      'ComicId',
      'CategoryId',
    });
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('T-0056-AC8 every file a generator reads imports no Flutter (R15)', () {
    final files = _pureSrcs();
    expect(files, hasLength(greaterThan(20)));
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

  test('T-0056-AC1 the domain, the blocs and the flags hold no floating '
      'point: money is integer cents', () {
    final offenders = [
      for (final f in _pureSrcs())
        if (_floatingPoint.hasMatch(_code(File(_path(f)).readAsStringSync())))
          f,
    ];
    expect(offenders, isEmpty);
  });

  test('T-0056-AC8 the checks read both quote styles and see a double '
      '(controls)', () {
    expect(_flutter.hasMatch('import "package:flutter/widgets.dart";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter/widgets.dart';"), isTrue);
    expect(_flutter.hasMatch('export "dart:ui";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter_bloc/x.dart';"), isTrue);
    expect(_flutter.hasMatch("import 'package:freezed/x.dart';"), isFalse);

    final e = _export.firstMatch('export "package:x/src/a.dart" show A, B;')!;
    expect(e.group(2), 'package:x/src/a.dart');
    expect(e.group(4), 'A, B');
    expect(_export.hasMatch('export "package:x/a.dart\';'), isFalse);

    for (final bad in [
      'final double price = 12.99;',
      'num total = 0;',
      'cents.toDouble()',
      '(cents / 100).round()',
      'x.floor()',
    ]) {
      expect(_floatingPoint.hasMatch(_code(bad)), isTrue, reason: bad);
    }
    expect(_floatingPoint.hasMatch(_code('// a double in a comment')), isFalse);
    expect(_floatingPoint.hasMatch(_code('final int cents = 1299;')), isFalse);
  });
}
