// The dashboard page: one bloc provider per section, the flag read once per
// visit, the visit's start (every section loads at once, once the page is
// shown), pull to refresh for every section, and the sections in order.

import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_dashboard/model.dart';
import 'package:mcgen/src/emit/feature_dashboard/text.dart';

void emitPage(Out ctx, DbModel m) {
  ctx.file('lib/src/presentation/page/${m.module}_page.dart', _page(m));
}

String _page(DbModel m) {
  final flagged = [
    for (final s in m.sections)
      if (s.flag != null) s,
  ];
  final uris = [
    'dart:async',
    'package:flutter/cupertino.dart',
    'package:flutter/material.dart',
    'package:flutter_bloc/flutter_bloc.dart',
    'package:mc_ds_navigation/mc_ds_navigation.dart',
    'package:mc_ds_tokens/mc_ds_tokens.dart',
    if (flagged.isNotEmpty) ...[
      'package:mc_feature_flags/mc_feature_flags.dart',
      m.uri('flags/${m.module}_flags.dart'),
    ],
    'package:mc_feature_flow/mc_feature_flow.dart',
    for (final s in m.sections) ...[
      m.uri('presentation/bloc/${s.snake}_bloc.dart'),
      m.uri('presentation/widget/${snakeCase(s.widget)}.dart'),
    ],
    m.uri(m.l10nFile),
  ];
  final flagFields = [
    for (final s in flagged)
      '  ${m.memberDoc('page.flag.${s.name}', 'Read once per visit: a section does not come and go under the reader\nwhen the remote flags arrive.')}'
          'late final bool _${s.camel} = context.di<FeatureFlagsReader>().value(\n'
          '    ${s.flag!.name},\n'
          '  );',
  ];
  final providers = [
    for (final s in m.sections)
      '        ${s.flag == null ? '' : 'if (_${s.camel}) '}BlocProvider(create: (c) => c.di<${s.bloc}>()),',
  ];
  final contentArgs = flagged.isEmpty
      ? '()'
      : '(${flagged.map((s) => '${s.camel}: _${s.camel}').join(', ')})';
  final ctor = flagged.isEmpty
      ? 'const ${m.homeContent}();'
      : 'const ${m.homeContent}({${flagged.map((s) => 'required this.${s.camel}').join(', ')}});';
  final fields = flagged.map((s) => '  final bool ${s.camel};').join('\n');
  final getters = flagged
      .map((s) => '  bool get ${s.camel} => widget.${s.camel};')
      .join('\n');
  final startAll = [
    for (final s in m.sections)
      s.flag == null
          ? '    context.read<${s.bloc}>().add(const ${s.event}.load());'
          : '    if (${s.camel}) {\n'
                '      context.read<${s.bloc}>().add(const ${s.event}.load());\n'
                '    }',
  ].join('\n');
  final refreshAll = [
    for (final s in m.sections)
      '      ${s.flag == null ? '' : 'if (${s.camel}) '}one((d) => context.read<${s.bloc}>().add(${s.event}.refresh(d))),',
  ].join('\n');
  final children = [
    for (final s in m.sections)
      '                ${s.flag == null ? '' : 'if (${s.camel}) '}const ${s.widget}(),',
  ].join('\n');
  return tpl(
    '''
<<imports>>

<<d_body_key>>const <<bodyKey>> = ValueKey<String>('<<module>>.body');

<<d_page>>class <<Page>> extends StatefulWidget {
  const <<Page>>({super.key});

  @override
  State<<<Page>>> createState() => _<<Page>>State();
}

class _<<Page>>State extends State<<<Page>>> {
<<flag_fields>>
  @override
  Widget build(BuildContext context) {
    // The only DI lookups in UI code (R17).
    return MultiBlocProvider(
      providers: [
<<providers>>
      ],
      child: <<Content>><<content_args>>,
    );
  }
}

class <<Content>> extends StatefulWidget {
  <<ctor>>

<<fields>>

  @override
  State<<<Content>>> createState() => <<Content>>State();
}

class <<Content>>State extends State<<<Content>>> {
  bool _started = false;

<<getters>>

<<d_deps>>  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = FlowScope.maybeOf(context)?.outerIsCurrent ?? true;
    if (shown && !_started) {
      _started = true;
      _startAll(context);
    }
  }

  /// The visit starts: every section loads at once, each on its own.
  void _startAll(BuildContext context) {
<<start_all>>
  }

  /// Pull to refresh: every section reloads at once, each on its own; the
  /// control closes when all of them have their answers.
  Future<void> _refreshAll(BuildContext context) {
    Future<void> one(void Function(Completer<void> done) add) {
      final done = Completer<void>();
      add(done);
      return done.future;
    }

    return Future.wait([
<<refresh_all>>
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.<<l10nExt>>;
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.<<title>>,
      ),
      body: CustomScrollView(
        key: <<bodyKey>>,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _refreshAll(context)),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: McSpacing.xl),
            sliver: SliverList.list(
              children: [
<<children>>
              ],
            ),
          ),
        ],
      ),
    );
  }
}
''',
    {
      'imports': imports(uris),
      'bodyKey': m.bodyKey,
      'd_body_key': m.doc(
        'page.body_key',
        "Key of the page's scrolling body, for tests.",
      ),
      'module': m.module,
      'd_page': m.doc(
        'page.doc',
        'The ${m.module.replaceAll('_', ' ')} page: provides one bloc per section and nothing\n'
            'else (Tide). Each section has its own bloc, request and states, and the\n'
            'visit\'s start reads every bloc and adds its `load`, so every section\n'
            'loads in parallel (F-0040 fact 6). A visit starts when the page is\n'
            'shown (F-0056 §1) and lasts as long as the page.',
      ),
      'Page': m.homePage,
      'Content': m.homeContent,
      'flag_fields': flagFields.isEmpty ? '' : '${flagFields.join('\n\n')}\n',
      'providers': providers.join('\n'),
      'content_args': contentArgs,
      'ctor': ctor,
      'fields': fields,
      'getters': getters.isEmpty ? '' : '$getters\n',
      'd_deps': m.memberDoc(
        'page.did_change_dependencies',
        'Depends on the flow\'s scope, so it runs again when whether the flow is\n'
            'visible in the app changes (`FlowScope.outerIsCurrent`).',
      ),
      'start_all': startAll,
      'refresh_all': refreshAll,
      'l10nExt': m.l10nExt,
      'title': m.key('Title'),
      'children': children,
    },
  ).replaceAll(RegExp(r'\n\n\n+'), '\n\n');
}
