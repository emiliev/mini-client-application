// The dashboard tests mcgen manages: the BDD steps it has a template for
// (opening the page, a section's states, retry, taps, the analytics counts),
// a failing stub for every other step, and the architecture test. The test
// env, the contract test, the flow-scope test, the golden and BUILD.bazel
// are the module's own (owned).
//
// A step calls into the env by name (`letSectionsLand`, `sectionPartKey`,
// ...); the env is where the module's fixtures and finders live, so a step
// file stays the same for every dashboard.

import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_dashboard/model.dart';
import 'package:mcgen/src/emit/feature_dashboard/step_templates.dart';
import 'package:mcgen/src/emit/feature_dashboard/text.dart';

/// The page noun of the steps (`the store`): `options.tests.page`.
String pageNoun(DbModel m) => m.tests['page'] ?? m.kSnake;

/// The key of [stepTemplates] this module's step [name] matches: the page
/// noun and the analytics prefix swapped for their placeholders.
String _templateKey(DbModel m, String name) => name
    .replaceAll('the_${m.kSnake}_tap', 'the_{k}_tap')
    .replaceAll('the_${pageNoun(m)}', 'the_{page}');

/// Every step file this module's features use that is not a shared step,
/// with the feature text of its first use.
Map<String, String> stepsUsed(DbModel m) {
  final usage = <String, String>{};
  for (final line in allSteps(m.spec.bdd).where((l) => !l.startsWith('#'))) {
    usage.putIfAbsent(stepFileName(line), () => stepText(line));
  }
  return {
    for (final e in usage.entries)
      if (!sharedSteps.contains(e.key)) e.key: e.value,
  };
}

void emitTests(Out ctx, DbModel m) {
  for (final MapEntry(key: name, value: text) in stepsUsed(m).entries) {
    final fn = stepFunctionName(text);
    final path = 'test/feature/step/$name.dart';
    final template = stepTemplates[_templateKey(m, name)];
    final usage = m.text('step.$name.usage', text);
    if (template == null) {
      ctx.file(path, _stub(fn, usage, text), owned: true);
      continue;
    }
    ctx.file(
      path,
      tpl(template, {
        'module': m.module,
        'K': m.k,
        'kc': m.kCamel,
        'body_key': m.bodyKey,
        'tapped_event': m.tappedEvent,
        'viewed_event': m.viewedEvent,
        'page': pageNoun(m),
        'and_clock': m.hasClock ? 'and the clock ' : '',
        'fn': fn,
        'usage': usage,
      }),
    );
  }
  ctx.file('test/architecture/architecture_test.dart', _architecture(m));
}

/// A step mcgen has no template for: written once, for a human to fill in.
String _stub(String fn, String usage, String text) {
  final params = [
    'WidgetTester tester',
    for (final (i, p) in stepParams(text).indexed)
      '${RegExp(r'^-?[0-9]+$').hasMatch(p) ? 'int' : 'String'} p${i + 1}',
  ];
  return "import 'package:flutter_test/flutter_test.dart';\n\n"
      '/// Usage: $usage\n'
      '///\n'
      '/// Written once by mcgen (no dashboard template); owned from now on.\n'
      'Future<void> $fn(${params.join(', ')}) async {\n'
      "  fail('step \"$fn\" is not written yet');\n"
      '}\n';
}

String _architecture(DbModel m) {
  final money = m.tests['money'] == 'true';
  final tag = m.tests['tag_barrel'] ?? 'T-0000-AC1';
  final tagMoney = m.tests['tag_money'] ?? tag;
  final shown = [m.flow, m.navigator, ...m.barrel];
  return tpl(_archTemplate, {
    'money_intro': money
        ? ', and\n// money never in floating point.'
        : '.',
    'dir': m.spec.moduleDir,
    'module': m.module,
    'tag': tag,
    'shown': [for (final s in shown) "      '$s',"].join('\n'),
    'min_pure': m.tests['min_pure'] ?? '20',
    'money_decl': money ? _moneyDecl : '',
    'money_test': money
        ? tpl(_moneyTest, {'tag_money': tagMoney})
        : '',
    'money_controls_title': money ? ' and see a double' : '',
    'money_controls': money ? _moneyControls : '',
  });
}

const _archTemplate = r"""
// Conformance of the package's shape (plan 01 §3.3), not a test of feature
// behaviour: R4 (the barrel), R15 (generators read Flutter-free files)<<money_intro>>
import 'dart:io';

import 'package:test/test.dart';

/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => '<<dir>>/$rel';

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
<<money_decl>>
List<String> _pureSrcs() =>
    File(_path('test/architecture/pure_srcs.txt'))
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

void main() {
  test('<<tag>> the barrel exports only the flow, the navigator and their '
      'argument types, each with show', () {
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
    expect(shown, {
<<shown>>
    });
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('<<tag>> every file a generator reads imports no Flutter (R15)', () {
    final files = _pureSrcs();
    expect(files, hasLength(greaterThan(<<min_pure>>)));
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

<<money_test>>  test('<<tag>> the checks read both quote styles<<money_controls_title>> '
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
<<money_controls>>  });
}
""";

const _moneyDecl = r"""

/// What floating-point money would need: a `double` or `num`, a conversion
/// to one, or a rounding call. Comments are stripped first.
final RegExp _floatingPoint = RegExp(
  r'\bdouble\b|\bnum\b|\.toDouble\(|\.round\(|\.floor\(|\.ceil\(|\.truncate\(',
);

String _code(String source) => source
    .replaceAll(RegExp(r'//.*'), '')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
""";

const _moneyTest = r"""
  test('<<tag_money>> the domain, the blocs and the flags hold no floating '
      'point: money is integer cents', () {
    final offenders = [
      for (final f in _pureSrcs())
        if (_floatingPoint.hasMatch(_code(File(_path(f)).readAsStringSync())))
          f,
    ];
    expect(offenders, isEmpty);
  });

""";

const _moneyControls = r"""

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
""";
