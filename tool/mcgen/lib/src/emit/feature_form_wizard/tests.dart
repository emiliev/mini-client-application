// The form/wizard tests mcgen renders for every module: the architecture
// test (R4 and R15). The test env, the steps and the flow-scope test are the
// module's own (`owned:`); a skeleton writes them once (skeleton_tests.dart).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';
import 'package:mcgen/src/emit/feature_form_wizard/text.dart';

void emitTests(EmitContext ctx, FwModel m) {
  ctx.library(_architectureTest(m));
}

DartLibrary _architectureTest(FwModel m) {
  final shown = [m.flow, m.navigator, ...m.barrel]..sort();
  final expected = [for (final s in shown) "      '$s',"].join('\n');
  final comment = m.optionalText('architecture.shown_comment');
  final text = tpl(
    r'''
/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => '<<moduleDir>>/$rel';

/// One export directive, in either quote style, with an optional `show`.
final RegExp _export = RegExp(
  rQQQexport\s+(['"])([^'"]+)\1\s*(show\s+([^;]+))?;QQQ,
  multiLine: true,
);

/// Any export directive at all, to check [_export] understood each one.
final RegExp _anyExport = RegExp(r'^\s*export\b', multiLine: true);

/// A Flutter import or export, in either quote style.
final RegExp _flutter = RegExp(
  rQQQ(import|export)\s+['"](package:flutter[a-z_]*/|dart:ui)QQQ,
);

void main() {
  test('<<tag>> the barrel exports only the flow, the navigator and the '
      '<<phrase>>, each with show', () {
    final barrel = File(_path('lib/<<module>>.dart')).readAsStringSync();
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
      expect(e.group(2), startsWith('package:<<module>>/src/'));
    }
<<comment>>    expect(shown, {
EXPECTED
    });
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('<<tag>> every file a generator reads imports no Flutter (R15)', () {
    final list = File(_path('test/architecture/pure_srcs.txt'));
    final files = list
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    expect(files, hasLength(greaterThan(<<over>>)));
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

  test('<<tag>> the checks read both quote styles', () {
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
}''',
    {
      'moduleDir': m.spec.moduleDir,
      'module': m.module,
      'tag': m.archTag,
      'phrase': m.text(
        'architecture.barrel_phrase',
        'argument and result types',
      ),
      'over': '${m.archPureOver}',
      'comment': comment == null ? '' : commentLines(comment, indent: '    '),
    },
  ).replaceAll('QQQ', "'''").replaceFirst('EXPECTED', expected);
  return DartLibrary(
    'test/architecture/architecture_test.dart',
    preamble: commentLines(
      m.text(
        'architecture_test.preamble',
        "Conformance of the package's shape (plan 01 §3.3), not a test of feature\n"
            'behaviour: R4 (the barrel) and R15 (generators read Flutter-free files).',
      ),
    ),
    imports: ['dart:io', 'package:test/test.dart'],
    decls: [RawDecl(Code(text))],
  );
}
