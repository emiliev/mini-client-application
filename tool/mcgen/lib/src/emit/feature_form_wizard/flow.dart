// The form/wizard flow layer: the barrel, DI, the root-import list, the
// navigator contract, the flow state and the flow (Tide nav 3.3, 3.4).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/spec/types.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';
import 'package:mcgen/src/emit/feature_form_wizard/text.dart';

const _widgets = 'package:flutter/widgets.dart';

void emitFlow(EmitContext ctx, FwModel m) {
  final nav = m.spec.navigator!;
  ctx.library(
    DartLibrary(
      'lib/${m.module}.dart',
      preamble: commentLines(
        m.text(
          'barrel.preamble',
          'The public surface (R4, checked by mc_arch_check and the architecture\n'
              "test): the flow, its navigator and the flow's argument and result types.\n"
              "No `library;` directive (Tide's `unnecessary_library_directive`).",
        ),
      ),
      exports: [
        Exports([m.flow, m.navigator, ...m.barrel]),
      ],
    ),
  );

  ctx.dartBrick(
    'feature_form_wizard_di',
    {'pascal': m.pascal},
    imports: {
      'lib/src/di/di_initializer.dart': [
        'dart:async',
        'package:${m.module}/src/di/di_initializer.config.dart',
      ],
    },
    defines: {
      'lib/src/di/di_initializer.dart': [m.diInitializer],
    },
  );

  ctx.library(
    DartLibrary(
      'lib/src/di/flow_scope.dart',
      decls: [
        RawDecl(
          _rootImports(m),
          name: m.rootImportsName,
          doc: m.text(
            'flow_scope.doc',
            "The root services this flow's container forwards (R17): the parameter\n"
                'types of every injectable constructor and `@factoryMethod` in the package,\n'
                'minus what the package registers itself and what the flow provides\n'
                '(`FeatureFlowController`, the navigator).\n'
                '\n'
                'HAND-WRITTEN FOR NOW. Plan 01 §4.5 has `mcgen wire` derive this file from\n'
                'the same analyzer input injectable reads, and `mcgen check` fail on drift\n'
                '(Phase D). Until then `test/flow_scope_test.dart` opens the flow over the\n'
                'production-shaped test root and resolves every registration, so a missing\n'
                'import fails a test, not the app.',
          ),
        ),
      ],
    ),
  );

  ctx.library(
    DartLibrary(
      'lib/src/navigator/${m.stem}_navigator.dart',
      decls: [
        ClassDecl(
          m.navigator,
          modifiers: 'abstract interface',
          doc: nav.doc,
          members: [
            for (final o in nav.outbound)
              RawMember(
                Code(
                  '${_ret(m, o.returns)} ${o.name}(${[for (final a in o.args) refs(m, a)].join(', ')});',
                ),
                doc: m.text(
                  'navigator.${o.name}',
                  'Leaves the feature: ${o.name}.',
                ),
              ),
          ],
        ),
      ],
    ),
  );

  ctx.library(
    DartLibrary(
      'lib/src/flow/${m.stem}_flow_state.dart',
      parts: ['${m.stem}_flow_state.freezed.dart'],
      imports: ['package:freezed_annotation/freezed_annotation.dart'],
      decls: [
        RawDecl(
          Code(
            tpl(_flowState, {
              'FlowState': m.flowState,
              'd_class': docLines(
                m.text(
                  'flow_state.doc',
                  'What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,\n'
                      'so the bloc that reads it stays Flutter-free (R15).',
                ),
              ),
              'fields': documented([
                for (final f in m.stateFields)
                  (
                    f.doc,
                    '${f.defaultValue == null ? '' : '@Default(${refs(m, f.defaultValue!)}) '}${refs(m, f.type)} ${f.name},',
                  ),
              ]),
            }),
          ),
          name: m.flowState,
        ),
      ],
    ),
  );

  ctx.library(
    DartLibrary(
      'lib/src/flow/${m.stem}_flow.dart',
      imports: [
        _widgets,
        m.uriOf('di/di_initializer.dart'),
        m.uriOf('di/flow_scope.dart'),
        m.uriOf('flow/${m.stem}_flow_state.dart'),
        m.uriOf('l10n/${m.l10nFile}.dart'),
        m.uriOf('navigator/${m.stem}_navigator.dart'),
        'package:mc_feature_flow/mc_feature_flow.dart',
      ],
      decls: [
        RawDecl(
          Code(
            tpl(_flow, {
              'Flow': m.flow,
              'FlowState': m.flowState,
              'Navigator': m.navigator,
              'DIInitializer': m.diInitializer,
              'rootImports': m.rootImportsName,
              'L10n': m.l10nClass,
              'd_class': docLines(
                m.text(
                  'flow.doc',
                  "The feature's only entry point (R4): ${m.spec.description ?? m.module}\n"
                      '\n'
                      'Immutable after creation: the flow reads its arguments once, when its\n'
                      'scope opens.',
                ),
              ),
              'ctor_args': [
                for (final a in m.flowArgs)
                  '    ${a.isRequired ? 'required ' : ''}this.${a.name}'
                      '${a.defaultValue == null ? '' : ' = ${refs(m, a.defaultValue!)}'},\n',
              ].join(),
              'fields': documented([
                (null, 'final ${m.navigator} navigator;'),
                for (final a in m.flowArgs)
                  (a.doc, 'final ${refs(m, a.type)} ${a.name};'),
                (
                  m.text(
                    'flow.result_doc',
                    "The flow's result. Called at most once.",
                  ),
                  'final ValueChanged<${refs(m, m.resultType)}> onComplete;',
                ),
              ]),
              'key': m.flowKey == null
                  ? ''
                  : '    key: ValueKey(${refs(m, m.flowKey!)}),\n',
              'state': refs(m, m.flowStateExpr),
              'cast': refs(m, m.resultCast),
              'pages_comment': switch (m.optionalText('flow.pages_comment')) {
                final c? => commentLines(c, indent: '    '),
                null => '',
              },
              'pages': [
                for (final p in m.pages)
                  '      ${p.when == null ? '' : 'if (${refs(m, p.when!)}) '}'
                      "${p.isConst ? 'const ' : ''}McFlowPage(name: '${p.name}', child: ${refs(m, p.widget)}),\n",
              ].join(),
            }),
          ),
          name: m.flow,
        ),
      ],
    ),
  );
}

Code _rootImports(FwModel m) => Code(
  'const List<${ref('RootImport')}<Object>> ${m.rootImportsName} = [\n'
  '${[for (final t in m.rootImports) '  ${ref('RootImport')}<${ref(t)}>(),\n'].join()}'
  '];',
);

String _ret(FwModel m, TypeExpr? t) => t == null ? 'void' : refs(m, '$t');

const _flowState = r'''
<<d_class>>@freezed
abstract class <<FlowState>> with _$<<FlowState>> {
  const factory <<FlowState>>({
<<fields>>
  }) = _<<FlowState>>;
}''';

const _flow = r'''
<<d_class>>class <<Flow>> extends StatelessWidget {
  const <<Flow>>({
    required this.navigator,
    required this.onComplete,
<<ctor_args>>    super.key,
  });

<<fields>>

  @override
  Widget build(BuildContext context) => FeatureFlow<<<FlowState>>>(
<<key>>    flowInitializer: const <<DIInitializer>>(),
    rootImports: <<rootImports>>,
    provide: (scope) =>
        scope.registerSingleton<<<Navigator>>>(navigator),
    localizationsDelegates: const [<<L10n>>.delegate],
    state: <<state>>,
    onComplete: (result) => onComplete(<<cast>>),
<<pages_comment>>    onGeneratePages: (state) => [
<<pages>>    ],
  );
}''';
