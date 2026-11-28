// The search tests mcgen manages: the BDD steps it has a template for (the
// field, the recent searches, tapping a result, paging, the facet chips), a
// failing stub for every other step, and the architecture test. The test
// env, the contract test and the flow-scope test are the module's own
// (owned): `skeleton.dart` writes them once.
//
// A step calls into the env by name (`openSearch`, `tapResult`, `tapChip`,
// ...); the env is where the module's fixtures and finders live, so a step
// file stays the same for every search module.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const flutterTest = 'package:flutter_test/flutter_test.dart';
const _widgets = 'package:flutter/widgets.dart';
const _testUtils = 'package:mc_test_utils/mc_test_utils.dart';

/// One step file's template: its doc after the usage line, its signature
/// from the parameters on (`(WidgetTester tester) => f(tester);`), and the
/// libraries it imports by URI (`path:` ones are relative).
class _Step {
  const _Step(this.doc, this.signature, {this.imports = const []});

  final String doc;
  final String signature;
  final List<String> imports;
}

String envPath(SrModel m) => 'test/feature/util/${m.module}_env.dart';

void emitTests(EmitContext ctx, SrModel m) {
  final env = 'path:${envPath(m)}';
  final templates = _stepTemplates(m, env);
  final usage = <String, String>{};
  for (final line in allSteps(m.spec.bdd).where((l) => !l.startsWith('#'))) {
    usage.putIfAbsent(stepFileName(line), () => stepText(line));
  }
  for (final MapEntry(key: name, value: text) in usage.entries) {
    if (sharedSteps.contains(name)) continue;
    final fn = stepFunctionName(text);
    final t = templates[name];
    final path = 'test/feature/step/$name.dart';
    final usageLine = m.text('step.$name.usage', text);
    if (t == null) {
      ctx.library(_stub(path, fn, usageLine, text), owned: true);
      continue;
    }
    ctx.library(
      DartLibrary(
        path,
        imports: [flutterTest, env, ...t.imports],
        decls: [
          RawDecl(
            Code('Future<void> $fn${t.signature}'),
            name: fn,
            doc: 'Usage: $usageLine\n\n${m.text('step.$name.doc', t.doc)}',
          ),
        ],
      ),
    );
  }
  ctx.library(_architectureTest(m));
}

/// A step mcgen has no template for: written once, for a human to fill in.
DartLibrary _stub(String path, String fn, String usage, String text) {
  final params = [
    'WidgetTester tester',
    for (final (i, p) in stepParams(text).indexed)
      '${RegExp(r'^-?[0-9]+$').hasMatch(p) ? 'int' : 'String'} p${i + 1}',
  ];
  return DartLibrary(
    path,
    imports: [flutterTest],
    decls: [
      RawDecl(
        Code(
          'Future<void> $fn(${params.join(', ')}) async {\n'
          "  fail('step \"$fn\" is not written yet');\n"
          '}',
        ),
        name: fn,
        doc:
            'Usage: $usage\n\nWritten once by mcgen (no search template); owned from now on.',
      ),
    ],
  );
}

Map<String, _Step> _stepTemplates(SrModel m, String env) {
  final out = <String, _Step>{
    'i_open_the_search': _Step(
      'Enters the feature the way the app does: through its flow (barrel only),\n'
      'with the navigator passed in the constructor [tide-nav §3.1]. The flow\n'
      'reads the recent searches from storage before the step ends.',
      '(WidgetTester tester) => openSearch(tester);',
    ),
    'i_open_the_search_again': _Step(
      'Closes the open search flow (its scope, bloc and history instance go\n'
      'away) and opens a new one over the same app root and storage, as leaving\n'
      'the search and coming back does.',
      '(WidgetTester tester) => openSearch(tester);',
    ),
    'i_open_the_search_for': _Step(
      'Opens the flow with an initial query, as a link with `?q=spi` does, and\n'
      'lets it settle (the debounce fires within the step).',
      '(WidgetTester tester, String query) =>\n'
          '    openSearch(tester, initialQuery: query);',
    ),
    'i_open_the_search_for_without_waiting': _Step(
      'Opens the flow with an initial query and draws one frame: no fake time\n'
      'passes (a debounce would not have fired) and no real storage I/O\n'
      'completes (the recent searches are still being read).',
      '(\n  WidgetTester tester,\n  String query,\n) => openSearch(tester, initialQuery: query, wait: false);',
    ),
    'i_search_for_each_of': _Step(
      'Types each query in turn (`I type`), letting each search be answered\n'
      'before the next.',
      '(WidgetTester tester, String queries) async {\n'
          '  for (final query in listArgument(queries)) {\n'
          '    await iType(tester, query);\n'
          '  }\n'
          '}',
      imports: ['package:mc_test_steps/mc_test_steps.dart'],
    ),
    'i_tap_the_recent_search': _Step(
      'Taps the recent search [query] and draws one frame with no fake time\n'
      'passing (zero-delay timers still run): a search that waited for a\n'
      'debounce would not have gone out.',
      '(WidgetTester tester, String query) async {\n'
          '  final row = find\n'
          '      .descendant(of: find.byKey(searchHistoryKey), matching: find.text(query))\n'
          '      .hitTestable();\n'
          "  expect(row, findsOneWidget, reason: 'one recent search \"\$query\"');\n"
          '  await tester.tap(row);\n'
          '  await tester.pump(Duration.zero);\n'
          '}',
    ),
    'the_recent_searches_are': _Step(
      'The recent searches show, exactly these, most recent first.',
      '(WidgetTester tester, String queries) async =>\n'
          '    expect(shownHistory(tester), listArgument(queries));',
    ),
  };
  final arg = m.tests['result_arg'] ?? 'name';
  final tapDoc = m.tests['result_tap_doc'] ??
      'Scrolls the results until the row named [$arg] is on screen, then taps it\nonce.';
  out['i_tap_the_result'] = _Step(
    tapDoc,
    '(WidgetTester tester, String $arg) =>\n    tapResult(tester, $arg);',
  );
  out['i_tap_the_result_and_again_after_milliseconds'] = _Step(
    'Two taps on the row, [milliseconds] of fake time apart.',
    '(\n'
        '  WidgetTester tester,\n'
        '  String $arg,\n'
        '  int milliseconds,\n'
        ') => tapResult(\n'
        '  tester,\n'
        '  $arg,\n'
        '  times: 2,\n'
        '  between: Duration(milliseconds: milliseconds),\n'
        ');',
  );
  out['i_tap_the_result_twice_in_quick_succession'] = _Step(
    'Two taps on the row within one frame: both reach the row, so both open\n'
    'events reach the bloc.',
    '(\n'
        '  WidgetTester tester,\n'
        '  String $arg,\n'
        ') => tapResult(tester, $arg, times: 2);',
  );
  out['i_scroll_the_results_to_the_end'] = m.paged
      ? _Step(
          'Scrolls the list to its end and on while pages keep loading, until the\n'
          'last page arrived or a later page failed (its footer offers Retry).',
          '(WidgetTester tester) async {\n'
              '  await shownResults(tester);\n'
              '  final position = resultsPosition(tester);\n'
              '  position.jumpTo(position.maxScrollExtent);\n'
              '  await mcSettle(tester);\n'
              '}',
          imports: [_testUtils],
        )
      : _Step(
          'Rows and notes below the fold are built only once they come near the\n'
          'screen (a lazy list), so a step that looks at the end scrolls there.',
          '(WidgetTester tester) async {\n'
              '  final position = tester.state<ScrollableState>(resultsScrollable()).position;\n'
              '  position.jumpTo(position.maxScrollExtent);\n'
              '  await mcSettle(tester);\n'
              '}',
          imports: [_widgets, _testUtils],
        );
  if (m.paged) {
    out['i_scroll_the_results_until_the_next_page_loads'] = _Step(
      'Jumps to the end of what is loaded once and lets the answer arrive: the\n'
      'list asks for exactly the next page.',
      '(WidgetTester tester) async {\n'
          '  final position = resultsPosition(tester);\n'
          '  position.jumpTo(position.maxScrollExtent);\n'
          '  await mcSettle(tester);\n'
          '}',
      imports: [_testUtils],
    );
    for (final f in m.facets) {
      final key = 'search${pascalCase(f.name)}Key';
      out['i_tap_the_${snakeCase(f.name)}_chip'] = _Step(
        'Taps the ${f.name} chip [label], scrolling the chips until it is on screen.',
        '(WidgetTester tester, String label) =>\n    tapChip(tester, $key, label);',
      );
      out['the_${snakeCase(f.name)}_is_chosen'] = _Step(
        'Exactly the ${f.name} chip [label] is selected.',
        '(WidgetTester tester, String label) async =>\n'
            '    expect(selectedChips(tester, $key), [label]);',
      );
      if (f.type.endsWith('?')) {
        out['no_${snakeCase(f.name)}_is_chosen'] = _Step(
          'No ${f.name} chip is selected.',
          '(WidgetTester tester) async =>\n'
              '    expect(selectedChips(tester, $key), isEmpty);',
        );
      }
    }
    out['the_facets_are_not_shown'] = _Step(
      'No facet chips are on screen (the recent searches show instead).',
      '(WidgetTester tester) async {\n'
          '${[for (final f in m.facets) '  expect(find.byKey(search${pascalCase(f.name)}Key), findsNothing);'].join('\n')}\n'
          '}',
    );
  }
  for (final o in m.spec.navigator!.outbound.where((o) => o.args.length == 1)) {
    final lookup = m.tests['lookup.${o.name}'];
    if (lookup == null) continue;
    final id = o.args.single;
    final base = 'the_app_was_asked_to_${snakeCase(o.name)}';
    out[base] = _Step(
      'The navigator contract: `${o.name}` with [$arg]\'s id (from the fixture\n'
      'cast), exactly once, and nothing else.',
      '(\n'
          '  WidgetTester tester,\n'
          '  String $arg,\n'
          ') async {\n'
          '  final navigator = searchNavigator();\n'
          '  verify(\n'
          '    () => navigator.${o.name}($id($lookup($arg).id)),\n'
          '  ).called(1);\n'
          '  verifyNoMoreInteractions(navigator);\n'
          '}',
      imports: [
        'package:${m.module}/${m.module}.dart',
        'package:mocktail/mocktail.dart',
      ],
    );
    out['${base}_times'] = _Step(
      'The navigator contract: `${o.name}` with [$arg]\'s id, [times] times,\n'
      'and nothing else.',
      '(\n'
          '  WidgetTester tester,\n'
          '  String $arg,\n'
          '  int times,\n'
          ') async {\n'
          '  final navigator = searchNavigator();\n'
          '  verify(\n'
          '    () => navigator.${o.name}($id($lookup($arg).id)),\n'
          '  ).called(times);\n'
          '  verifyNoMoreInteractions(navigator);\n'
          '}',
      imports: [
        'package:${m.module}/${m.module}.dart',
        'package:mocktail/mocktail.dart',
      ],
    );
  }
  return out;
}

DartLibrary _architectureTest(SrModel m) {
  final barrelIds = <String>{
    for (final o in m.spec.navigator!.outbound) ...o.args,
  };
  final shown = [m.flow, m.navigator, ...barrelIds];
  final expected = [for (final s in shown) "      '$s',"].join('\n');
  final tag = m.tag('architecture');
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
  test('<<tag>>the barrel exports only the flow, the navigator and their '
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
EXPECTED
    });
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('<<tag>>every file a generator reads imports no Flutter (R15)', () {
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

  test('<<tag>>the checks read both quote styles', () {
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
    {'moduleDir': m.spec.moduleDir, 'module': m.module, 'tag': tag},
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
