// The skeleton's tests: the env, the steps the features use (a step with no
// template is a failing stub for a human to fill in) and the flow-scope test,
// all written once and owned afterwards.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';
import 'package:mcgen/src/emit/feature_form_wizard/skeleton_test_templates.dart';
import 'package:mcgen/src/emit/feature_form_wizard/text.dart';

const _flutterTest = 'package:flutter_test/flutter_test.dart';

/// The env's public names a step or the flow-scope test calls.
const _envNames = [
  'Mock',
  'flowResults',
  'flowUnderTest',
  'stepCount',
  'stepBodyKey',
  'savingKey',
  'textFieldLabelled',
  'enterText',
  'expectFieldText',
  'expectErrorUnder',
  'endSessionElsewhere',
  'FlowStateView',
  'flowState',
  'flowAnchor',
  'ensureContainer',
  'bddSetUpAll',
];

/// [text] with the env's names as references, so mcgen writes the relative
/// import. A name after a `.` or inside a `$`-interpolation stays plain.
String _envRefs(String text) => text.replaceAllMapped(
  RegExp(
    r'(?<![A-Za-z0-9_$.])(' +
        _envNames.where((n) => n != 'Mock').join('|') +
        r')(?![A-Za-z0-9_])',
  ),
  (x) => '«${x[1]}»',
);

class _Template {
  const _Template(this.doc, this.params, this.body, {this.imports = const []});

  final String doc;
  final String params;
  final String body;
  final List<String> imports;
}

void emitSkeletonTests(EmitContext ctx, FwModel m, Map<String, String> v) {
  final sk = m.skeleton!;
  final env = 'test/feature/util/${m.stem}_env.dart';
  final barrel = 'package:${m.module}/${m.module}.dart';
  for (final n in _envNames) {
    if (n == 'Mock') continue;
    ctx.symbols.define(n, 'path:$env');
  }
  ctx.symbols.define('Mock${m.navigator}', 'path:$env');
  ctx.library(
    DartLibrary(
      env,
      imports: [
        'package:flutter/material.dart',
        _flutterTest,
        barrel,
        'package:mc_api_auth/mc_api_auth.dart',
        'package:mc_di/mc_di.dart',
        'package:mc_feature_flow/testing.dart',
        'package:mc_test_utils/mc_test_utils.dart',
        'package:mocktail/mocktail.dart',
        for (final p in _fixturePackages(sk))
          'package:mc_fixtures_$p/mc_fixtures_$p.dart',
      ],
      decls: [
        RawDecl(
          Code(
            tpl(envTemplate, {
              ...v,
              'setup': [
                for (final p in _fixturePackages(sk))
                  '  ${p}FixtureSets.forEach(McFixtureSets.register);\n',
              ].join(),
            }),
          ),
        ),
      ],
    ),
    owned: true,
  );

  final templates = _templates(m, barrel);
  final usage = <String, String>{};
  for (final line in allSteps(m.spec.bdd)) {
    usage.putIfAbsent(stepFileName(line), () => stepText(line));
  }
  for (final MapEntry(key: name, value: text) in usage.entries) {
    if (sharedSteps.contains(name)) continue;
    final fn = stepFunctionName(text);
    final t = templates[name];
    final path = 'test/feature/step/$name.dart';
    if (t == null) {
      ctx.library(_stub(path, fn, text), owned: true);
      continue;
    }
    ctx.library(
      DartLibrary(
        path,
        imports: [_flutterTest, ...t.imports],
        decls: [
          RawDecl(
            Code(
              templateRefs(
                'Future<void> $fn${t.params} async ${_envRefs(t.body)}',
              ),
            ),
            name: fn,
            doc: 'Usage: $text\n\n${t.doc}',
          ),
        ],
      ),
      owned: true,
    );
  }

  final fills = [
    for (final step in sk.steps.take(sk.steps.length - 1))
      '[${[for (final f in step.fields) "('${f.label}', 'x')"].join(', ')}]',
  ];
  final next = m.en('${m.camel}Next');
  ctx.library(
    DartLibrary(
      'test/flow_scope_test.dart',
      preamble: commentLines(
        m.text(
          'flow_scope_test.preamble',
          'The flow as a unit of wiring, entered through the barrel only. R17: its\n'
              'root imports (lib/src/di/flow_scope.dart) are complete, and a missing one\n'
              'fails at flow creation, naming the type (`mcgen wire` will generate the\n'
              'list, Phase D). The bloc is the flow\'s own: one per flow, shared by the\n'
              'step pages, closed with the flow.',
        ),
      ),
      imports: [
        'package:dio/dio.dart',
        _flutterTest,
        'package:mc_di/mc_di.dart',
        'package:mc_ds_navigation/mc_ds_navigation.dart',
        'package:mc_feature_flow/mc_feature_flow.dart',
        'package:mc_monitoring/mc_monitoring.dart',
        'package:mc_test_steps/mc_test_steps.dart',
        'package:mc_test_utils/mc_test_utils.dart',
      ],
      decls: [
        RawDecl(
          Code(
            templateRefs(
              _envRefs(
                tpl(flowScopeTestTemplate, {
                  ...v,
                  'signed_in': sk.signedIn,
                  'setupAll': 'bddSetUpAll',
                  'next': next,
                  'fixtures': [
                    for (final f in sk.fixtures)
                      "    session.backend.useFixtureSet('$f');\n",
                  ].join(),
                  'fills':
                      '      const fills = <List<(String, String)>>[${fills.join(', ')}];',
                }),
              ),
            ),
          ),
        ),
      ],
    ),
    owned: true,
  );
}

/// The fixture packages of the skeleton's fixture sets (`identity.default`
/// is in `mc_fixtures_identity`), sorted.
List<String> _fixturePackages(FwSkeleton sk) =>
    {for (final f in sk.fixtures) f.split('.').first}.toList()..sort();

/// A step mcgen has no template for: written once, for a human to fill in.
DartLibrary _stub(String path, String fn, String text) {
  final params = [
    'WidgetTester tester',
    for (final (i, p) in stepParams(text).indexed)
      '${RegExp(r'^-?[0-9]+$').hasMatch(p) ? 'int' : 'String'} p${i + 1}',
  ];
  return DartLibrary(
    path,
    imports: [_flutterTest],
    decls: [
      RawDecl(
        Code(
          'Future<void> $fn(${params.join(', ')}) async {\n'
          "  fail('step \"$fn\" is not written yet');\n"
          '}',
        ),
        name: fn,
        doc:
            'Usage: $text\n\nWritten once by mcgen (no form_wizard template); owned from now on.',
      ),
    ],
  );
}

Map<String, _Template> _templates(FwModel m, String barrel) {
  final sk = m.skeleton!;
  return {
    'i_open_the_${sk.noun.replaceAll(' ', '_')}_flow': const _Template(
      'Enters the feature the way the app does: through its flow (barrel only),\n'
          'with the navigator passed in the constructor and a result recorder as\n'
          '`onComplete` [tide-nav §3.1].',
      '(WidgetTester tester)',
      '{\n'
          '  await ensureContainer();\n'
          '  await initFlow(tester, flowUnderTest);\n'
          '  await mcSettle(tester);\n'
          '}',
      imports: ['package:mc_test_utils/mc_test_utils.dart'],
    ),
    'i_enter_in_the_field': const _Template(
      'Replaces the text of the field found by its [label], in any locale, then\n'
          'moves the focus away so the field reports it was touched.',
      '(WidgetTester tester, String text, String label)',
      '=> enterText(tester, label, text);',
    ),
    'the_error_shows_under_the_field': const _Template(
      'The text field labelled [label] shows [text] as its error (the\n'
          "`McTextField`'s error slot, announced as a live region).",
      '(WidgetTester tester, String text, String label)',
      '=> expectErrorUnder(tester, label, text);',
    ),
    'the_field_shows': const _Template(
      'The text field labelled [label] shows [text].',
      '(WidgetTester tester, String label, String text)',
      '=> expectFieldText(tester, label, text);',
    ),
    'i_am_on_step': const _Template(
      "The flow shows that step's page on top (its state's deepest step), and\n"
          'the step bar reads "Step n of N".',
      '(WidgetTester tester, int step)',
      '{\n'
          '  expect(\n'
          '    flowState(tester, flowAnchor()).step,\n'
          '    step - 1,\n'
          "    reason: 'the flow is on step \$step',\n"
          '  );\n'
          "  expect(find.text('Step \$step of \$stepCount'), findsOneWidget);\n"
          '}',
    ),
    'the_flow_completed_with': _Template(
      'The flow ended once, with that id as its result (`onComplete`): what\n'
          'the wiring hands back to the caller.',
      '(WidgetTester tester, String id)',
      "=> expect(flowResults(), [${sk.resultName}(id)], reason: 'the flow result');",
      imports: [barrel],
    ),
    'the_flow_has_not_completed': const _Template(
      '`onComplete` was not called: the flow has no result.',
      '(WidgetTester tester)',
      "=> expect(flowResults(), isEmpty, reason: 'no result yet');",
    ),
    'the_session_ends_elsewhere': const _Template(
      'The user signs out from another screen: the real `AuthApi.signOut`,\n'
          'inside `runAsync` (the session clears a real file, F-0038).',
      '(WidgetTester tester)',
      '=> endSessionElsewhere(tester);',
    ),
  };
}
