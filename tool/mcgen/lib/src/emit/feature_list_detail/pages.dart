// The list-detail pages and widgets: the list page with its paged grid of
// tiles, the in-flow preview page with its actions, and one widget per
// preview section (Tide 5.10: the page provides its bloc, the content maps
// states with `state.when`).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

const _page = 'lib/src/presentation/page';
const _widget = 'lib/src/presentation/widget';

void emitPages(EmitContext ctx, LdModel m) {
  ctx.dartBrick(
    'feature_list_detail_failure',
    const {},
    defines: {
      '$_widget/failure_message.dart': ['failureMessage'],
    },
  );
  _listPage(ctx, m);
  _tile(ctx, m);
  _previewPage(ctx, m);
  for (final s in m.sections) {
    _section(ctx, m, s);
  }
}

void _listPage(EmitContext ctx, LdModel m) {
  ctx.library(
    DartLibrary(
      '$_page/${m.module}_page.dart',
      imports: [dartAsync, material],
      decls: [
        RawDecl(
          Code(
            "const ${m.gridKey} = ValueKey<String>('${m.module}.grid');",
          ),
          name: m.gridKey,
          doc: 'Key of the ${m.items} grid, for tests.',
        ),
        ClassDecl(
          m.listPage,
          superclass: Code('StatelessWidget'),
          doc: 'The list page: provides its bloc and nothing else (Tide).',
          members: [
            RawMember(Code('const ${m.listPage}({super.key});')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '  // The only DI lookup in UI code (R17).\n'
                '  return ${ref('BlocProvider')}(\n'
                '    create: (context) => context.di${use('McFlowContext')}<${ref(m.listBloc)}>(),\n'
                '    child: const _${m.listPage}Content(),\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
        ClassDecl(
          '_${m.listPage}Content',
          superclass: Code('StatelessWidget'),
          doc: 'Maps each bloc state to UI.',
          members: [
            RawMember(Code('const _${m.listPage}Content();')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '  final l10n = ${ref(m.l10nClass)}.of(context);\n'
                '  final core = ${ref('McL10nCoreL10n')}.of(context);\n'
                '  final bloc = context.read${use('ReadContext')}<${ref(m.listBloc)}>();\n'
                '  void retry() => bloc.add(const ${ref(m.listEvent)}.retry());\n'
                '  return Scaffold(\n'
                '    appBar: ${ref('McAppBar')}(\n'
                '      // The flow has its own navigator: this leaves the flow from its root page.\n'
                '      leading: const ${ref('McFlowBackButton')}(),\n'
                '      title: l10n.${m.key('Title')},\n'
                '    ),\n'
                '    body: ${ref('BlocBuilder')}<${ref(m.listBloc)}, ${ref(m.listState)}>(\n'
                '      builder: (context, state) => state.when(\n'
                '        loading: () => ${ref('McLoading')}(semanticLabel: l10n.${m.key('Loading')}),\n'
                '        failure: (error, _) => ${ref('McErrorView')}(\n'
                '          title: l10n.${m.key('ErrorTitle')},\n'
                '          message: ${ref('failureMessage')}(error, core),\n'
                '          retryLabel: core.commonRetry,\n'
                '          onRetry: retry,\n'
                '        ),\n'
                '        success: (page) => ${ref('McPagedGrid')}<${ref(m.listEntity)}>(\n'
                '          key: ${m.gridKey},\n'
                '          state: page,\n'
                '          cellHeight: (width, textScaler) => ${ref('McMediaCard')}.heightFor(\n'
                '            width: width,\n'
                '            textScaler: textScaler,\n'
                '            hasSubtitle: false,\n'
                '          ),\n'
                '          itemBuilder: (context, ${m.itemCamel}, _) =>\n'
                '              ${ref(m.tile)}(${m.itemCamel}: ${m.itemCamel}),\n'
                '          onLoadMore: () => bloc.add(const ${ref(m.listEvent)}.loadMore()),\n'
                '          onRetry: retry,\n'
                '          onRefresh: () {\n'
                '            final done = Completer<void>();\n'
                '            bloc.add(${ref(m.listEvent)}.refresh(done));\n'
                '            return done.future;\n'
                '          },\n'
                '          emptyTitle: l10n.${m.key('EmptyTitle')},\n'
                '          emptyMessage: l10n.${m.key('EmptyMessage')},\n'
                '          errorTitle: l10n.${m.key('ErrorTitle')},\n'
                '          footerErrorMessage: l10n.${m.key('LoadMoreFailed')},\n'
                '          retryLabel: core.commonRetry,\n'
                '          loadingLabel: l10n.${m.key('Loading')},\n'
                '        ),\n'
                '      ),\n'
                '    ),\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void _tile(EmitContext ctx, LdModel m) {
  ctx.library(
    DartLibrary(
      '$_widget/${snakeCase(m.tile)}.dart',
      imports: [widgets],
      decls: [
        ClassDecl(
          m.tile,
          superclass: Code('StatelessWidget'),
          doc: m.text(
            'tile.doc',
            'One ${m.item} in the grid: its ${m.titleField} and bundled art on a media card.\n'
                'A tap dispatches an event; only the bloc changes the flow (plan 01 §4.1).',
          ),
          members: [
            RawMember(
              Code(
                'const ${m.tile}({required this.${m.itemCamel}, super.key});',
              ),
            ),
            RawMember(Code('final ${ref(m.listEntity)} ${m.itemCamel};')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) => ${ref('McMediaCard')}(\n'
                '  title: ${m.itemCamel}.${m.titleField},\n'
                '  image: ${m.itemCamel}.${m.imageField},\n'
                '  onTap: () => context.read${use('ReadContext')}<${ref(m.listBloc)}>().add(\n'
                '    ${ref(m.listEvent)}.preview(${m.itemCamel}),\n'
                '  ),\n'
                ');',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void _previewPage(EmitContext ctx, LdModel m) {
  final item = m.itemCamel;
  final providers = [
    '${ref('BlocProvider')}(\n'
        '  create: (context) =>\n'
        '      context.di${use('McFlowContext')}<${ref(m.previewBloc)}>(parameter: $item),\n'
        ')',
    for (final s in m.sections)
      '${ref('BlocProvider')}(\n'
          '  create: (context) =>\n'
          '      context.di<${ref(s.bloc)}>(parameter: $item),\n'
          ')',
  ];
  final content = '_${m.itemPascal}PreviewContent';
  final provide = providers.length == 1
      ? 'return ${providers.single.replaceFirst(RegExp(r',\n\)$'), ',\n  child: const $content(),\n)')};'
      : 'return ${ref('MultiBlocProvider')}(\n'
            '  providers: [\n'
            '${providers.map((p) => '$p,').join('\n')}\n'
            '  ],\n'
            '  child: const $content(),\n'
            ');';
  final buttons = [
    for (final a in m.actions)
      '${ref('McButton')}(\n'
          '  label: l10n.${m.key(a.stringKey)},\n'
          '  expand: true,\n'
          '  onPressed: () => context.read${use('ReadContext')}<${ref(m.previewBloc)}>().add(\n'
          '    const ${ref(m.previewEvent)}.${a.event}(),\n'
          '  ),\n'
          '),',
  ].join('\nconst ${ref('McGap')}.lg(),\n');
  final sections = m.sections.isEmpty
      ? ''
      : 'const ${ref('McGap')}.lg(),\n'
            '${commentLines(m.text('preview.sections_comment', 'Full width: the section header and the rows bring their own\ninsets (DS lists are edge to edge).'))}'
            '${[for (final s in m.sections) 'const ${ref(s.name)}(),'].join('\nconst ${ref('McGap')}.lg(),\n')}\n';
  final artDefault = m.sections.isEmpty
      ? "Key of the preview's ${m.item} art, for tests."
      : "Key of the preview's ${m.item} art (the ${m.sections.first.words} below it have\n"
            '${m.sections.first.image}s of their own), for tests.';
  ctx.library(
    DartLibrary(
      '$_page/${snakeCase(m.previewPage)}.dart',
      imports: [material],
      decls: [
        RawDecl(
          Code(
            "const ${m.previewTitleKey} = ValueKey<String>(\n  '${m.module}.preview.title',\n);",
          ),
          name: m.previewTitleKey,
          doc:
              "Key of the preview's title (the ${m.item}'s ${m.titleField}), for tests.",
        ),
        RawDecl(
          Code(
            "const ${m.previewArtKey} = ValueKey<String>('${m.module}.preview.art');",
          ),
          name: m.previewArtKey,
          doc: m.text('preview.art_key', artDefault),
        ),
        ClassDecl(
          m.previewPage,
          superclass: Code('StatelessWidget'),
          doc: m.text(
            'preview_page.doc',
            'The in-flow preview of one ${m.item} (a flow page, not a route): its art,\n'
                'its ${m.titleField} and its actions, each of which leaves the feature. The\n'
                "flow keys it by the ${m.item}'s id, so another ${m.item} gets a new page\n"
                'and blocs.',
          ),
          members: [
            RawMember(
              Code('const ${m.previewPage}({required this.$item, super.key});'),
            ),
            RawMember(
              Code('final ${ref(m.listEntity)} $item;'),
              doc: "The flow state's selection.",
            ),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '$provide\n'
                '}',
              ),
            ),
          ],
        ),
        ClassDecl(
          content,
          superclass: Code('StatelessWidget'),
          members: [
            RawMember(Code('const $content();')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '  final l10n = ${ref(m.l10nClass)}.of(context);\n'
                '  return ${ref('BlocBuilder')}<${ref(m.previewBloc)}, ${ref(m.listEntity)}>(\n'
                '    builder: (context, $item) => Scaffold(\n'
                '      appBar: ${ref('McAppBar')}(\n'
                '        title: $item.${m.titleField},\n'
                '        titleKey: ${m.previewTitleKey},\n'
                '      ),\n'
                '      body: ListView(\n'
                '        padding: ${ref('McInsets')}.vertical,\n'
                '        children: [\n'
                '          Padding(\n'
                '            padding: ${ref('McInsets')}.horizontal,\n'
                '            child: Column(\n'
                '              crossAxisAlignment: CrossAxisAlignment.stretch,\n'
                '              children: [\n'
                '                ${ref('McImage')}(\n'
                '                  key: ${m.previewArtKey},\n'
                '                  image: $item.${m.imageField},\n'
                '                  variant: ${ref('ImageVariant')}.${m.artVariant},\n'
                '                ),\n'
                '                const ${ref('McGap')}.lg(),\n'
                '$buttons\n'
                '              ],\n'
                '            ),\n'
                '          ),\n'
                '$sections'
                '        ],\n'
                '      ),\n'
                '    ),\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void _section(EmitContext ctx, LdModel m, LdSection s) {
  String k(String suffix) => m.key('Preview${s.strings}$suffix');
  final items = s.items.replaceAll(' ', '');
  ctx.library(
    DartLibrary(
      '$_widget/${s.snake}.dart',
      imports: [material],
      decls: [
        RawDecl(
          Code(
            "const ${s.camel}Key = ValueKey<String>('${m.module}.preview.${s.key}');",
          ),
          name: '${s.camel}Key',
          doc: "Key of the preview's ${s.words}, for tests.",
        ),
        RawDecl(
          Code(
            'const double ${_cam(s, '${pascalCase(s.image)}Width')} = 36;\n'
            'const double ${_cam(s, '${pascalCase(s.image)}Height')} = 48;',
          ),
          name: _cam(s, '${pascalCase(s.image)}Width'),
          doc: "A ${_singular(s)}'s ${s.image} thumbnail, portrait (3:4).",
        ),
        ClassDecl(
          s.name,
          superclass: Code('StatelessWidget'),
          doc: m.text(
            'section.${s.name}.doc',
            "The preview's ${s.words}: a section title, then the ${s.items}, each a\n"
                'link that leaves the feature (through the bloc). Its failure is inline,\n'
                'with Retry; the preview above it stays.',
          ),
          members: [
            RawMember(Code('const ${s.name}({super.key});')),
            RawMember(
              Code(
                '@override\n'
                'Widget build(BuildContext context) {\n'
                '  final l10n = ${ref(m.l10nClass)}.of(context);\n'
                '  final core = ${ref('McL10nCoreL10n')}.of(context);\n'
                '  final bloc = context.read${use('ReadContext')}<${ref(s.bloc)}>();\n'
                '  return Column(\n'
                '    key: ${s.camel}Key,\n'
                '    crossAxisAlignment: CrossAxisAlignment.stretch,\n'
                '    children: [\n'
                '      ${ref('McSectionHeader')}(title: l10n.${k('')}),\n'
                '      ${ref('BlocBuilder')}<${ref(s.bloc)}, ${ref(s.state)}>(\n'
                '        builder: (context, state) => state.when(\n'
                '          loading: () => ${ref('McLoading')}(\n'
                '            semanticLabel: l10n.${k('Loading')},\n'
                '          ),\n'
                '          failure: (_, _) => Padding(\n'
                '            padding: ${ref('McInsets')}.horizontal,\n'
                '            child: Column(\n'
                '              crossAxisAlignment: CrossAxisAlignment.start,\n'
                '              children: [\n'
                '                Text(l10n.${k('Failed')}),\n'
                '                ${ref('McButton')}(\n'
                '                  label: core.commonRetry,\n'
                '                  variant: ${ref('McButtonVariant')}.tertiary,\n'
                '                  onPressed: () => bloc.add(const ${ref(s.event)}.load()),\n'
                '                ),\n'
                '              ],\n'
                '            ),\n'
                '          ),\n'
                '          success: ($items) => $items.isEmpty\n'
                '              ? Padding(\n'
                '                  padding: ${ref('McInsets')}.horizontal,\n'
                '                  child: Text(l10n.${k('Empty')}),\n'
                '                )\n'
                '              : Column(\n'
                '                  children: [\n'
                '                    for (final ${s.item} in $items)\n'
                '                      ListTile(\n'
                '                        // The ${s.image} makes the row recognisable at a glance.\n'
                '                        leading: ${ref('McImage')}(\n'
                '                          image: ${s.item}.${s.image},\n'
                '                          variant: ${ref('ImageVariant')}.${s.imageVariant},\n'
                '                          width: ${_cam(s, '${pascalCase(s.image)}Width')},\n'
                '                          height: ${_cam(s, '${pascalCase(s.image)}Height')},\n'
                '                        ),\n'
                '                        title: Text(${s.item}.${s.title}),\n'
                '                        trailing: const Icon(Icons.chevron_right),\n'
                '                        onTap: () =>\n'
                '                            bloc.add(${ref(s.event)}.open(${s.item}.id)),\n'
                '                      ),\n'
                '                  ],\n'
                '                ),\n'
                '        ),\n'
                '      ),\n'
                '    ],\n'
                '  );\n'
                '}',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// `relatedComicCoverWidth`: the section's singular, camelCase, plus [what].
String _cam(LdSection s, String what) {
  final single = _singular(s).split(' ');
  return [
        single.first,
        for (final w in single.skip(1))
          '${w[0].toUpperCase()}${w.substring(1)}',
      ].join() +
      what;
}

/// `related comics` -> `related comic`: the section's words with its item.
String _singular(LdSection s) {
  final w = s.words.split(' ');
  return [...w.take(w.length - 1), s.item].join(' ');
}
