// The section-detail presentation layer. The favourite toggle and the failure
// text are managed; the page, its sections and the inner page are what the
// exemplars wrote by hand, so they are emitted once as a working starting
// point and owned afterwards (ADR-0017).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/favourite_templates.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';

const _page = 'lib/src/presentation/page';
const _widget = 'lib/src/presentation/widget';

void emitPages(EmitContext ctx, ScModel m) {
  ctx.dartBrick(
    'feature_list_detail_failure',
    const {},
    defines: {
      '$_widget/failure_message.dart': ['failureMessage'],
    },
  );
  final toggle = tpl(
    favouriteToggleTemplate
        .replaceFirst('context.read<', 'context.read${use('ReadContext')}<')
        .replaceFirst(
          'context.mcPalette.error',
          'context.mcPalette${use('McThemeContext')}.error',
        ),
    {
      'Item': m.itemPascal,
      'Prefix': m.prefix,
      'prefixCamel': m.prefixCamel,
      'module': m.module,
    },
  ).trimRight();
  ctx.library(
    DartLibrary(
      '$_widget/favourite_toggle.dart',
      imports: [material],
      decls: [RawDecl(Code(toggle), name: 'FavouriteToggle')],
    ),
  );
  _detailsPage(ctx, m);
  if (m.cover case final c?) _coverPage(ctx, m, c);
}

void _detailsPage(EmitContext ctx, ScModel m) {
  final item = m.itemCamel;
  final related = m.related;
  final params = related == null ? item : '$item, ${related.camel}';
  final rows = [
    for (final o in m.opens)
      if (o.field != null)
        '        ${ref('McButton')}(\n'
            "          key: const ValueKey('${m.module}.open.${o.label}'),\n"
            '          label: l10n.${m.key('Open${pascalLabel(o.label)}')},\n'
            '          onPressed: () => context.read${use('ReadContext')}<${ref(m.detailsBloc)}>().add(\n'
            '            ${m.detailsEvent}.${o.calls}($item.${o.field}),\n'
            '          ),\n'
            '        ),\n',
  ].join();
  ctx.library(
    DartLibrary(
      '$_page/${snakeCase(m.item)}_details_page.dart',
      imports: [material],
      decls: [
        RawDecl(
          Code(
            "const ${m.detailsBodyKey} = ValueKey<String>('${m.module}.body');",
          ),
          name: m.detailsBodyKey,
          doc: "Key of the details page's scrolling body, for tests.",
        ),
        ClassDecl(
          m.detailsPage,
          superclass: Code('StatelessWidget'),
          doc: 'The details page: provides its blocs and nothing else (Tide).',
          members: [
            RawMember(Code('const ${m.detailsPage}({super.key});')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '  // The only DI lookups in UI code (R17).\n'
                '  return ${ref('MultiBlocProvider')}(\n'
                '    providers: [\n'
                '      ${ref('BlocProvider')}(create: (context) => context.di${use('McFlowContext')}<${ref(m.detailsBloc)}>()),\n'
                '      ${ref('BlocProvider')}(create: (context) => context.di<${ref(m.favouriteBloc)}>()),\n'
                '    ],\n'
                '    child: const _${m.detailsPage}Content(),\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
        ClassDecl(
          '_${m.detailsPage}Content',
          superclass: Code('StatelessWidget'),
          doc: 'Maps each bloc state to UI.',
          members: [
            RawMember(Code('const _${m.detailsPage}Content();')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '  final l10n = ${ref(m.l10nClass)}.of(context);\n'
                '  final core = ${ref('McL10nCoreL10n')}.of(context);\n'
                '  return ${ref('BlocBuilder')}<${ref(m.detailsBloc)}, ${m.detailsState}>(\n'
                '    builder: (context, state) => Scaffold(\n'
                '      appBar: ${ref('McAppBar')}(\n'
                '        leading: const ${ref('McFlowBackButton')}(),\n'
                '        title: state.maybeWhen(\n'
                '          success: ($params) => $item.${m.titleField},\n'
                '          orElse: () => l10n.${m.key('Title')},\n'
                '        ),\n'
                '      ),\n'
                '      body: state.when(\n'
                '        loading: () => ${ref('McLoading')}(semanticLabel: l10n.${m.key('Loading')}),\n'
                '        notFound: () => ${ref('McEmptyView')}(\n'
                '          title: l10n.${m.key('NotFoundTitle')},\n'
                '          message: l10n.${m.key('NotFoundMessage')},\n'
                '        ),\n'
                '        failure: (error, _) => ${ref('McErrorView')}(\n'
                '          title: l10n.${m.key('ErrorTitle')},\n'
                '          message: ${ref('failureMessage')}(error, core),\n'
                '          retryLabel: core.commonRetry,\n'
                '          onRetry: () => context.read<${ref(m.detailsBloc)}>().add(\n'
                '            const ${m.detailsEvent}.load(),\n'
                '          ),\n'
                '        ),\n'
                '        success: ($params) => _Sections($item: $item),\n'
                '      ),\n'
                '    ),\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
        ClassDecl(
          '_Sections',
          superclass: Code('StatelessWidget'),
          doc: 'The loaded ${m.itemWords}, section by section.',
          members: [
            RawMember(
              Code('const _Sections({required this.$item});'),
            ),
            RawMember(Code('final ${ref(m.entity)} $item;')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '${rows.isEmpty ? '' : '  final l10n = ${ref(m.l10nClass)}.of(context);\n'}'
                '  return ListView(\n'
                '    key: ${m.detailsBodyKey},\n'
                '    padding: const EdgeInsets.all(16),\n'
                '    children: [\n'
                '$rows'
                '      const ${ref('FavouriteToggle')}(),\n'
                '    ],\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
      ],
    ),
    owned: true,
  );
}

String pascalLabel(String label) => pascalCase(label);

void _coverPage(EmitContext ctx, ScModel m, ScCover c) {
  final item = m.itemCamel;
  ctx.library(
    DartLibrary(
      '$_page/${c.pageFile}',
      imports: [material],
      decls: [
        ClassDecl(
          c.page,
          superclass: Code('StatelessWidget'),
          doc:
              'The ${m.itemWords}\'s ${c.field}, inside the flow (a flow page, not a route).',
          members: [
            RawMember(
              Code('const ${c.page}({required this.$item, super.key});'),
            ),
            RawMember(Code('final ${ref(m.entity)} $item;')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) => Scaffold(\n'
                '  appBar: ${ref('McAppBar')}(title: $item.${m.titleField}),\n'
                '  body: Center(child: Text($item.${m.titleField})),\n'
                ');',
              ),
            ),
          ],
        ),
      ],
    ),
    owned: true,
  );
}
