// The section-detail flow layer: the barrel, DI, the root-import list, the
// navigator contract, the flow state and the flow (Tide nav 3.3, 3.4).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';

void emitFlow(EmitContext ctx, ScModel m) {
  final nav = m.spec.navigator!;
  ctx.library(
    DartLibrary(
      'lib/${m.module}.dart',
      preamble: commentLines(
        m.text(
          'barrel.preamble',
          'The public surface (R4, checked by mc_arch_check and the architecture\n'
              "test): the flow, its navigator, the flow's argument type and the\n"
              "navigator's argument types. No `library;` directive (Tide's\n"
              '`unnecessary_library_directive`).',
        ),
      ),
      exports: [
        Exports([m.flow, m.navigator, for (final i in m.ids) i.name]),
      ],
    ),
  );

  ctx.library(
    DartLibrary(
      'lib/src/di/di_initializer.dart',
      imports: [
        dartAsync,
        'package:${m.module}/src/di/di_initializer.config.dart',
      ],
      decls: [
        ClassDecl(
          m.diInitializer,
          superclass: Code(ref('McDIInitializer')),
          doc: m.text(
            'di.doc',
            "Registers this feature's types in its flow's own container (Tide's\n"
                'boilerplate shape; plan 01 §3.3).',
          ),
          members: [
            RawMember(Code('const ${m.diInitializer}() : super(_init);')),
          ],
        ),
        RawDecl(
          Code(
            '@${ref('InjectableInit')}()\n'
            'FutureOr<${ref('GetIt')}> _init(${ref('GetIt')} getIt, String? environment) =>\n'
            '    getIt.init(environment: environment);',
          ),
        ),
      ],
    ),
  );

  final analytics = m.analytics != null;
  final rootImports = [
    if (analytics) 'AnalyticsTracker',
    'Dio',
    'EventBus',
    'Monitoring',
    'SessionReader',
  ];
  ctx.library(
    DartLibrary(
      'lib/src/di/flow_scope.dart',
      decls: [
        RawDecl(
          Code(
            'const List<${ref('RootImport')}<Object>> ${m.rootImports} = [\n'
            '${[for (final n in rootImports) '  ${ref('RootImport')}<${ref(n)}>(),'].join('\n')}\n'
            '];',
          ),
          name: m.rootImports,
          doc: m.text(
            'flow_scope.doc',
            'The root services this flow\'s container forwards (R17): the parameter\n'
                'types of every injectable constructor and `@factoryMethod` in the package,\n'
                'minus what the package registers itself and what the flow provides\n'
                '(`FeatureFlowController`, the navigator).'
                '${analytics ? " `AnalyticsTracker` is also the\nflow observer's." : ''}\n'
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
                  o.name == 'requestSignIn'
                      ? 'The favourite needs a signed-in user. Completes with true once someone\n'
                            'signed in, false when the user backed out. The feature does not know\n'
                            'how signing in works; the app decides (a sheet, a route).'
                      : 'Leaves the feature: ${words(o.name)}.',
                ),
              ),
          ],
        ),
      ],
    ),
  );

  final cover = m.cover;
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
            'What the flow shows, not which page is on top (plan 01 §4.1): the\n'
                '${m.item} it opened on. Pure Dart, so the blocs that read it stay\n'
                'Flutter-free (R15).',
          ),
          annotations: [Code('@${ref('freezed')}')],
          members: [
            RawMember(
              Code(
                'const factory ${m.flowState}({\n'
                '${documented([
                  (m.text('flow_state.id', 'The ${m.item} the flow opened on; the flow starts from the id alone (plan 01 §4.4).'), 'required ${ref(m.itemIdType)} ${m.idArg},'),
                  if (cover != null) (
                      m.text(
                        'flow_state.cover',
                        'The loaded ${m.item} whose ${cover.field} page is open.',
                      ),
                      '${ref(m.entity)}? ${cover.field},',
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

  final pages = StringBuffer()
    ..write(
      "  ${ref('McFlowPage')}(\n"
      '    name: ${analytics ? ref(m.analytics!.screenConst) : "'details'"},\n'
      '    arguments: state.${m.idArg},\n'
      '    child: const ${ref(m.detailsPage)}(),\n'
      '  ),\n',
    );
  if (cover != null) {
    pages.write(
      '  if (state.${cover.field} case final ${m.itemCamel}?)\n'
      "    ${ref('McFlowPage')}(\n"
      "      name: '${cover.pageName}',\n"
      '      arguments: ${m.itemCamel}.id,\n'
      '      child: ${ref(cover.page)}(key: ValueKey(${m.itemCamel}.id), ${m.itemCamel}: ${m.itemCamel}),\n'
      '    ),\n',
    );
  }
  final observers = analytics
      ? '// The flow\'s pages are screens: resolved inside the flow, without a\n'
            '// dependency on the host route (F-0056 section 4).\n'
            'observers: [\n'
            "  ${ref('AnalyticsFlowObserver')}(\n"
            '    (context) => context.di<${ref('AnalyticsTracker')}>()${use('McFlowContext')},\n'
            '    host: (context) => ${ref('FlowScope')}.read(context).outerRoute,\n'
            '  ),\n'
            '],\n'
      : '';
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
            "The feature's only entry point (R4): one ${m.item}'s page in sections,\n"
                'whose actions leave the feature through [navigator].\n'
                '\n'
                'The app builds it from a route with the navigator implementation from\n'
                'its wiring; tests pass a mock. It starts from the id alone (plan 01 §4.4).\n'
                '\n'
                'Immutable after creation: the flow reads [navigator] and [${m.idArg}] once,\n'
                'when its scope opens (`provide:` runs once per flow instance). A rebuild\n'
                'with a different navigator keeps the first one; a different [${m.idArg}]\n'
                'builds a new flow (its `FeatureFlow` is keyed by it), with a fresh scope,\n'
                'state and first page.',
          ),
          members: [
            RawMember(
              Code(
                'const ${m.flow}({required this.navigator, required this.${m.idArg}, super.key});',
              ),
            ),
            RawMember(
              Code(
                documented([
                  (null, 'final ${ref(m.navigator)} navigator;'),
                  (
                    m.text('flow.id', 'The ${m.item} to show.'),
                    'final ${ref(m.itemIdType)} ${m.idArg};',
                  ),
                ]),
              ),
            ),
            Method(
              Code('Widget build(BuildContext context)'),
              annotations: [Code('@override')],
              arrow: Code(
                '${ref('FeatureFlow')}<${ref(m.flowState)}>(\n'
                'key: ValueKey(${m.idArg}),\n'
                'flowInitializer: const ${ref(m.diInitializer)}(),\n'
                'rootImports: ${ref(m.rootImports)},\n'
                'provide: (scope) =>\n'
                '    scope.registerSingleton<${ref(m.navigator)}>(navigator),\n'
                'localizationsDelegates: const [${ref(m.l10nClass)}.delegate],\n'
                '$observers'
                'state: ${ref(m.flowState)}(${m.idArg}: ${m.idArg}),\n'
                'onGeneratePages: (state) => [\n'
                '$pages'
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
