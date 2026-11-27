// Conformance of the package's shape (plan 01 §3.3), not a test of feature
// behaviour: R4 (the barrel), R15 (generators read Flutter-free files), R7
// (src/ only from test/contract and, ADR-0015, test/unit) and ADR-0014 (the engine is
// pure Dart: no Flutter, no timers, no clock, integer arithmetic only).
import 'dart:io';

import 'package:test/test.dart';

/// Bazel only (the lists are genrule outputs): the test runs at the
/// runfiles root, where the package sits at its workspace path.
const String _pkg = 'feature/trivia/trivia_quiz';

String _path(String rel) => '$_pkg/$rel';

/// One export directive, in either quote style, with an optional `show`.
final RegExp _export = RegExp(
  r'''export\s+(['"])([^'"]+)\1\s*(show\s+([^;]+))?;''',
  multiLine: true,
);

/// Any export directive at all, to check [_export] understood each one.
final RegExp _anyExport = RegExp(r'^\s*export\b', multiLine: true);

/// Every import or export directive's URI, in either quote style.
final RegExp _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+(['"])([^'"]+)\1''',
  multiLine: true,
);

/// A Flutter import or export, in either quote style.
final RegExp _flutter = RegExp(
  r'''(import|export)\s+['"](package:flutter[a-z_]*/|dart:ui)''',
);

/// What the engine may import besides its own files: annotations and the
/// pure-Dart image value type of its model. No `dart:async` (timers), no
/// `dart:io`, no clock, no Flutter.
const Set<String> _engineMayImport = {
  'package:freezed_annotation/freezed_annotation.dart',
  'package:mc_media/mc_media.dart',
};

/// Floating point: a `double` or `num`, a conversion to one, a rounding
/// call, or `/` (only `~/` divides integers). Comments and strings are
/// stripped first.
final RegExp _floatingPoint = RegExp(
  r'\bdouble\b|\bnum\b|\.toDouble\(|\.round\(|\.floor\(|\.ceil\(|\.truncate\(|(?<![~/])/(?![/=*])',
);

String _code(String source) => source
    .replaceAll(RegExp(r'//.*'), '')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r"'[^'\n]*'"), "''")
    .replaceAll(RegExp(r'"[^"\n]*"'), '""');

List<String> _lines(String rel) =>
    File(_path(rel))
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

/// The problems of the engine closure rooted at [files] (package-relative
/// paths), whose sources [read] returns: an import of anything not allowed,
/// a first-party import outside the engine, or floating point.
List<String> engineProblems(
  List<String> files,
  String Function(String file) read,
) {
  final problems = <String>[];
  final engine = files.toSet();
  for (final file in files) {
    final source = read(file);
    for (final m in _directive.allMatches(source)) {
      final uri = m.group(2)!;
      if (uri.startsWith('package:trivia_quiz/')) {
        final target = 'lib/${uri.substring('package:trivia_quiz/'.length)}';
        if (!engine.contains(target) && !target.endsWith('.freezed.dart')) {
          problems.add('$file imports $uri, outside the engine');
        }
      } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
        // A relative part (`trivia.freezed.dart`) is generated code.
        if (!uri.endsWith('.freezed.dart')) {
          problems.add('$file uses the relative URI $uri');
        }
      } else if (!_engineMayImport.contains(uri)) {
        problems.add('$file imports $uri');
      }
    }
    if (_floatingPoint.hasMatch(_code(source))) {
      problems.add('$file uses floating point');
    }
  }
  return problems;
}

Iterable<File> _dartFiles(String dir) =>
    Directory(_path(dir))
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

void main() {
  test('T-0064-AC7 the barrel exports only the flow, the navigator and its '
      'argument type, each with show', () {
    final barrel = File(_path('lib/trivia_quiz.dart')).readAsStringSync();
    final exports = _export.allMatches(barrel).toList();
    expect(exports, isNotEmpty);
    expect(
      exports,
      hasLength(_anyExport.allMatches(barrel).length),
      reason: 'every export directive is one this check understands',
    );
    final shown = <String>{};
    for (final e in exports) {
      expect(e.group(3), isNotNull, reason: '${e.group(2)} exports all');
      shown.addAll(e.group(4)!.split(',').map((s) => s.trim()));
      expect(e.group(2), startsWith('package:trivia_quiz/src/'));
    }
    expect(shown, {'TriviaQuizFlow', 'TriviaQuizNavigator', 'ComicId'});
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('T-0064-AC7 every file a generator reads imports no Flutter (R15)', () {
    final files = _lines('test/architecture/pure_srcs.txt');
    expect(files, hasLength(greaterThan(15)));
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

  test('T-0064-AC7 the engine is pure Dart: no Flutter, no timers, no clock, '
      'integer arithmetic only, and its imports stay inside it', () {
    final files = _lines('test/architecture/engine_srcs.txt');
    expect(files, contains('lib/src/domain/engine/trivia_engine.dart'));
    expect(files, contains('lib/src/domain/engine/scoring.dart'));
    expect(
      engineProblems(files, (f) => File(_path(f)).readAsStringSync()),
      isEmpty,
    );
  });

  test('T-0064-AC7 the engine check catches a Flutter import, a timer, a '
      'leak out of the engine and floating point (negative controls)', () {
    const files = [
      'lib/src/domain/engine/a.dart',
      'lib/src/domain/engine/b.dart',
    ];
    List<String> check(String a) => engineProblems(
      files,
      (f) => f.endsWith('a.dart')
          ? a
          : "import 'package:trivia_quiz/src/domain/engine/a.dart';",
    );
    expect(check("import 'package:mc_media/mc_media.dart';"), isEmpty);
    expect(check("import 'package:flutter/foundation.dart';"), hasLength(1));
    expect(check('import "package:flutter/widgets.dart";'), hasLength(1));
    expect(check("import 'dart:ui';"), hasLength(1));
    expect(check("import 'dart:async';"), hasLength(1));
    expect(check("import 'package:clock/clock.dart';"), hasLength(1));
    expect(
      check("import 'package:trivia_quiz/src/presentation/page/x.dart';"),
      hasLength(1),
    );
    expect(check("export 'package:flutter/material.dart';"), hasLength(1));
    expect(check("part 'a.freezed.dart';"), isEmpty);
    for (final bad in [
      'final double ratio = 0;',
      'num total = 0;',
      'int f(int a) => a.toDouble().round();',
      'int f(int a, int b) => (a / b).floor();',
      'final x = 50 * a / b;',
    ]) {
      expect(check(bad), hasLength(1), reason: bad);
    }
    for (final good in [
      'int f(int a, int b) => 50 * a ~/ b;',
      '// a / b in a comment, and a double',
      "const s = 'a/b double';",
    ]) {
      expect(check(good), isEmpty, reason: good);
    }
  });

  test('T-0064-AC7 src/ is imported only from test/contract and test/unit '
      '(R7; plain unit tests of pure logic are allowed, ADR-0015)', () {
    final offenders = [
      for (final f in _dartFiles('test'))
        if (!f.path.contains('/test/contract/') &&
            !f.path.contains('/test/unit/') &&
            _directive
                .allMatches(f.readAsStringSync())
                .any((m) => m.group(2)!.startsWith('package:trivia_quiz/src/')))
          f.path,
    ];
    expect(offenders, isEmpty);
    // Unit tests reach only the pure-Dart engine and its model, never a
    // bloc, page or the flow (those are tested through BDD, ADR-0015).
    final engine = _lines('test/architecture/engine_srcs.txt').toSet();
    for (final f in _dartFiles('test/unit')) {
      for (final m in _directive.allMatches(f.readAsStringSync())) {
        final uri = m.group(2)!;
        if (uri.startsWith('package:trivia_quiz/')) {
          expect(
            engine,
            contains('lib/${uri.substring('package:trivia_quiz/'.length)}'),
            reason: '${f.path} imports $uri',
          );
        }
      }
    }
  });

  test('T-0064-AC7 no lint is suppressed in the package', () {
    final offenders = [
      for (final dir in ['lib', 'test'])
        for (final f in _dartFiles(dir))
          if (RegExp(r'//\s*ignore(_for_file)?:')
              .hasMatch(f.readAsStringSync()))
            f.path,
    ];
    expect(offenders, isEmpty);
    // The control is built from two literals, so this file has none.
    expect(
      RegExp(r'//\s*ignore:').hasMatch(
        '//'
        ' ignore: x',
      ),
      isTrue,
    );
  });
}
