// The list-detail flow layer: the barrel, DI, the root-import list, the
// navigator contract, the flow state and the flow (Tide nav 3.3, 3.4).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

void emitFlow(EmitContext ctx, LdModel m) {
  final nav = m.spec.navigator!;
  ctx.library(
    DartLibrary(
      'lib/${m.module}.dart',
      preamble: commentLines(
        m.text(
          'barrel.preamble',
          'The public surface (R4, checked by mc_arch_check and the architecture\n'
              "test): the flow, its navigator and the navigator's argument types. No\n"
              "`library;` directive (Tide's `unnecessary_library_directive`).",
        ),
      ),
      exports: [
        Exports([m.flow, m.navigator, ...m.barrelIds]),
      ],
    ),
  );

  ctx.dartBrick(
    'feature_list_detail_di',
    {'module': m.module, 'pascal': m.pascal},
    imports: {
      'lib/src/di/di_initializer.dart': [
        dartAsync,
        'package:${m.module}/src/di/di_initializer.config.dart',
      ],
    },
    defines: {
      'lib/src/di/di_initializer.dart': [m.diInitializer],
    },
  );

  ctx.library(
    DartLibrary(
      'lib/src/navigator/${m.module}_navigator.dart',
      decls: [
        ClassDecl(
          m.navigator,
          modifiers: 'abstract interface',
          doc: nav.doc,
          members: [
            for (final o in nav.outbound)
              RawMember(
                Code(
                  '${o.returns == null ? 'void' : 'Future<${ty(o.returns!)}>'} '
                  '${o.name}(${[for (final a in o.args) '${tyName(a)} id'].join(', ')});',
                ),
                doc: m.text(
                  'navigator.${o.name}',
                  'Leaves the feature: ${words(o.name)}.',
                ),
              ),
          ],
        ),
      ],
    ),
  );

  final entity = m.listEntity;
  ctx.library(
    DartLibrary(
      'lib/src/flow/${m.module}_flow_state.dart',
      parts: ['${m.module}_flow_state.freezed.dart'],
      decls: [
        ClassDecl(
          m.flowState,
          modifiers: 'abstract',
          mixins: [Code('_\$${m.flowState}')],
          doc: m.text(
            'flow_state.doc',
            'What the flow has selected, not which page shows (plan 01 §4.1): a\n'
                '[preview] puts the preview page on top of the list. Pure Dart, so the\n'
                'blocs that update it stay Flutter-free (R15).',
          ),
          annotations: [Code('@${ref('freezed')}')],
          members: [
            RawMember(
              Code(
                'const factory ${m.flowState}({\n'
                '${documented([
                  for (final f in m.filters) (f.doc, '${ty(f.type)} ${f.name},'),
                  (
                    m.text(
                      'flow_state.preview',
                      'The ${m.item} whose preview is open: the summary the list loaded, so\n'
                          'the preview needs no second request and the repository stays stateless.',
                    ),
                    '${ref(entity)}? preview,',
                  ),
                ])}\n'
                '}) = _${m.flowState};',
              ),
            ),
          ],
        ),
      ],
    ),
  );

  final filterKey = switch (m.filters.length) {
    0 => '',
    1 => 'key: ValueKey(${m.filters.single.arg}),\n',
    _ => 'key: ValueKey((${m.filters.map((f) => f.arg).join(', ')})),\n',
  };
  final state = m.filters.isEmpty
      ? 'const ${ref(m.flowState)}()'
      : '${ref(m.flowState)}(${m.filters.map((f) => '${f.name}: ${f.arg}').join(', ')})';
  ctx.library(
    DartLibrary(
      'lib/src/flow/${m.module}_flow.dart',
      imports: [widgets],
      decls: [
        ClassDecl(
          m.flow,
          superclass: Code('StatelessWidget'),
          doc: m.text(
            'flow.doc',
            "The feature's only entry point (R4): a paged grid of ${m.items} whose\n"
                'preview opens inside the flow, and whose actions leave the feature\n'
                'through [navigator].\n'
                '\n'
                'The app builds it from a route with the navigator implementation from\n'
                'its wiring; tests pass a mock.',
          ),
          members: [
            RawMember(
              Code(
                'const ${m.flow}({required this.navigator, '
                '${[for (final f in m.filters) 'this.${f.arg},'].join(' ')}'
                ' super.key});',
              ),
            ),
            RawMember(
              Code(
                documented([
                  (null, 'final ${ref(m.navigator)} navigator;'),
                  for (final f in m.filters)
                    (f.argDoc, 'final ${ty(f.type)} ${f.arg};'),
                ]),
              ),
            ),
            Method(
              Code(
                'Widget build(BuildContext context)',
              ),
              annotations: [Code('@override')],
              arrow: Code(
                '${ref('FeatureFlow')}<${ref(m.flowState)}>(\n'
                '$filterKey'
                'flowInitializer: const ${ref(m.diInitializer)}(),\n'
                'rootImports: ${ref(m.rootImports)},\n'
                'provide: (scope) =>\n'
                '    scope.registerSingleton<${ref(m.navigator)}>(navigator),\n'
                'localizationsDelegates: const [${ref(m.l10nClass)}.delegate],\n'
                'state: $state,\n'
                'onGeneratePages: (state) => [\n'
                "  const ${ref('McFlowPage')}(name: 'list', child: ${ref(m.listPage)}()),\n"
                '  if (state.preview case final ${m.itemCamel}?)\n'
                '    ${ref('McFlowPage')}(\n'
                "      name: 'preview',\n"
                '      arguments: ${m.itemCamel}.id,\n'
                '      child: ${ref(m.previewPage)}(\n'
                '        key: ValueKey(${m.itemCamel}.id),\n'
                '        ${m.itemCamel}: ${m.itemCamel},\n'
                '      ),\n'
                '    ),\n'
                '],\n'
                ')',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

extension on LdModel {
  /// The id types the barrel exports: the navigator's argument types.
  List<String> get barrelIds => [
    for (final o in spec.navigator!.outbound)
      for (final a in o.args) a,
  ].toSet().toList();
}
