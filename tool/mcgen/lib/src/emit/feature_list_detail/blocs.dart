// The list-detail blocs: the paged list, the preview and one per preview
// section (Tide 5.8: hand-style sealed events with private cases, freezed
// `sealed` states with private cases, monitoring in `McBloc`).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

const _bloc = 'lib/src/presentation/bloc';

void emitBlocs(EmitContext ctx, LdModel m) {
  _listBloc(ctx, m);
  _previewBloc(ctx, m);
  for (final s in m.sections) {
    _sectionBloc(ctx, m, s);
  }
}

/// A sealed event class with private cases: [cases] are (factory doc,
/// factory signature, case class, fields).
List<Decl> _events(
  String name,
  String doc,
  List<(String?, String, String, List<(String, String)>)> cases, {
  List<(String?, String, List<(String, String)>)> internal = const [],
}) {
  String ctorArgs(List<(String, String)> fields) =>
      fields.map((f) => 'this.${f.$2}').join(', ');
  ClassDecl caseClass(String c, List<(String, String)> fields, String? doc) =>
      ClassDecl(
        c,
        modifiers: 'final',
        superclass: Code(name),
        doc: doc,
        members: [
          RawMember(Code('const $c(${ctorArgs(fields)});')),
          if (fields.isNotEmpty)
            RawMember(
              Code(
                [for (final f in fields) 'final ${f.$1} ${f.$2};'].join('\n'),
              ),
            ),
        ],
      );
  return [
    ClassDecl(
      name,
      modifiers: 'sealed',
      doc: doc,
      members: [
        RawMember(Code('const $name();')),
        for (final (doc, factory, c, _) in cases)
          RawMember(Code('const factory $name.$factory = $c;'), doc: doc),
      ],
    ),
    for (final (_, _, c, fields) in cases) caseClass(c, fields, null),
    for (final (doc, c, fields) in internal) caseClass(c, fields, doc),
  ];
}

String _failureCase(String state, String? doc) =>
    '${docLines(doc)}@${ref('Implements')}<${ref('McFailureState')}>()\n'
    'const factory $state.failure(\n'
    '  ${ref('ApiFailure')} error, {\n'
    '  StackTrace? stackTrace,\n'
    '}) = _Failure;';

void _listBloc(EmitContext ctx, LdModel m) {
  final e = m.listEntity;
  final item = m.itemCamel;
  final eventsPath = '$_bloc/${m.module}_event.dart';
  final statePath = '$_bloc/${m.module}_state.dart';
  ctx.library(
    DartLibrary(
      eventsPath,
      partOf: '${m.module}_bloc.dart',
      imports: [dartAsync],
      decls: _events(
        m.listEvent,
        m.text(
          'list_event.doc',
          'What the list page asks for. Hand-written sealed events with private cases\n'
              '(Tide), so a page can only create them through the factories.',
        ),
        [
          ('Starts over with the first page.', 'load()', '_Load', []),
          (
            'The grid scrolled past its load-more threshold.',
            'loadMore()',
            '_LoadMore',
            [],
          ),
          (
            'Repeats the request that failed (first page or a later one).',
            'retry()',
            '_Retry',
            [],
          ),
          (
            'Pull to refresh: reloads the first page and keeps the items meanwhile.\n'
                '[done] completes when the reload settled, so the refresh control closes.',
            'refresh(Completer<void> done)',
            '_Refresh',
            [('Completer<void>', 'done')],
          ),
          (
            'A tile was tapped: its preview opens inside the flow (ignored while a\n'
                'preview is open).',
            'preview(${ref(e)} $item)',
            '_Preview',
            [(ref(e), item)],
          ),
          for (final a in m.listActions)
            (
              m.text(
                'list_action.${a.event}.doc',
                a.doc ?? 'The app bar\'s ${words(a.event)} action.',
              ),
              '${a.event}()',
              '_${pascalCase(a.event)}',
              const <(String, String)>[],
            ),
        ],
        internal: [
          (
            'Internal: the paging controller produced a new state.',
            '_PageChanged',
            [('${ref('PagedState')}<${ref(e)}>', 'page')],
          ),
        ],
      ),
    ),
  );
  ctx.library(
    DartLibrary(
      statePath,
      partOf: '${m.module}_bloc.dart',
      decls: [
        ClassDecl(
          m.listState,
          modifiers: 'sealed',
          mixins: [Code('_\$${m.listState}')],
          doc:
              'Tide\'s state shape: private cases read with `state.when` (R16); freezed 4\n'
              'adds only `sealed`.',
          annotations: [Code('@${ref('freezed')}')],
          members: [
            RawMember(
              Code('const factory ${m.listState}.loading() = _Loading;'),
              doc: 'The first page is on its way.',
            ),
            RawMember(
              Code(
                'const factory ${m.listState}.success(${ref('PagedState')}<${ref(e)}> page) =\n'
                '    _Success;',
              ),
              doc:
                  'Something to show: items (perhaps loading or failing more), or a\n'
                  'settled empty list.',
            ),
            RawMember(
              Code(
                _failureCase(
                  m.listState,
                  'The first page failed. `McBloc` reports it to monitoring (D-16).',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  final filterArgs = [
    for (final f in m.filters) '${f.name}: _flow.state.${f.name},',
  ].join('\n');
  ctx.library(
    DartLibrary(
      '$_bloc/${m.module}_bloc.dart',
      parts: [
        '${m.module}_bloc.freezed.dart',
        '${m.module}_event.dart',
        '${m.module}_state.dart',
      ],
      decls: [
        RawDecl(
          Code('const int ${m.pageSizeConst} = ${m.pageSize};'),
          name: m.pageSizeConst,
          doc: m.text(
            'list_bloc.page_size',
            '${pascalCase(m.items)} per request.',
          ),
        ),
        for (final a in m.listActions)
          RawDecl(
            Code(
              'const Duration ${a.event}Guard = Duration(milliseconds: ${a.guardMs});',
            ),
            name: '${a.event}Guard',
            doc: m.text(
              'list_action.${a.event}.guard',
              'How long after `${a.event}` a second one is ignored: the second tap\n'
                  'of a double tap.',
            ),
          ),
        ClassDecl(
          m.listBloc,
          modifiers: 'final',
          superclass: Code(
            '${ref('McBloc')}<${ref(m.listEvent)}, ${ref(m.listState)}>',
          ),
          doc: m.text(
            'list_bloc.doc',
            "The list page's bloc: pages of ${m.items} through a [PagingController]\n"
                '(load, load more, refresh, retry), and the tap that opens a preview, which\n'
                'is flow state, not a route (plan 01 §4.1).\n'
                '\n'
                'Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never\n'
                'Flutter, so every generator that reads it runs on analyzer summaries.',
          ),
          annotations: [Code('@${ref('injectable')}')],
          members: [
            RawMember(
              Code(
                '${m.listBloc}(this._repository, this._flow, ${m.listActions.isEmpty ? '' : 'this._navigator, '}${ref('Monitoring')} monitoring)\n'
                '  : super(const ${m.listState}.loading(), monitoring: monitoring) {\n'
                '  _paging = ${ref('PagingController')}<${ref(e)}>(\n'
                '    fetcher: (request) => _repository.fetchPage(\n'
                '      ${ref(m.query)}(\n'
                '        offset: request.offset,\n'
                '        limit: request.limit,\n'
                '${filterArgs.isEmpty ? '' : '$filterArgs\n'}'
                '      ),\n'
                '    ),\n'
                '    // The controller reports outside any handler; an event brings each\n'
                '    // state back into the bloc, so only a handler emits.\n'
                '    onState: (page) => add(_PageChanged(page)),\n'
                '    limit: ${m.pageSizeConst},\n'
                '  );\n'
                '  on<${m.listEvent}>(_onEvent);\n'
                '  add(const ${m.listEvent}.load());\n'
                '}',
              ),
            ),
            RawMember(
              Code(
                'final ${ref(m.repository)} _repository;\n'
                'final ${ref('FeatureFlowController')}<${ref(m.flowState)}> _flow;\n'
                '${m.listActions.isEmpty ? '' : 'final ${ref(m.navigator)} _navigator;\n'}'
                '${[for (final a in m.listActions) 'Timer? _${a.event}Guard;\n'].join()}'
                'late final ${ref('PagingController')}<${ref(e)}> _paging;',
              ),
            ),
            RawMember(
              Code(
                'Future<void> _onEvent(\n'
                '  ${m.listEvent} event,\n'
                '  ${ref('Emitter')}<${m.listState}> emit,\n'
                ') async {\n'
                '  switch (event) {\n'
                '    case _Load():\n'
                '      await _paging.loadFirst();\n'
                '    case _LoadMore():\n'
                '      await _paging.loadMore();\n'
                '    case _Retry():\n'
                '      await _paging.retry();\n'
                '    case _Refresh(:final done):\n'
                '      try {\n'
                '        await _paging.refresh();\n'
                '      } finally {\n'
                '        done.complete();\n'
                '      }\n'
                '    case _Preview(:final $item):\n'
                '      // One preview at a time: a second tap while the first preview slides\n'
                '      // in must not replace what the open preview shows and opens.\n'
                '      if (_flow.state.preview == null) {\n'
                '        _flow.update((s) => s.copyWith(preview: $item));\n'
                '      }\n'
                '${[for (final a in m.listActions) _listActionCase(m, a)].join()}'
                '    case _PageChanged(:final page):\n'
                '      emit(_toState(page));\n'
                '  }\n'
                '}',
              ),
            ),
            RawMember(
              Code(
                'static ${m.listState} _toState(${ref('PagedState')}<${ref(e)}> page) =>\n'
                '    switch (page) {\n'
                '      PagedState(items: [], failure: final failure?) =>\n'
                '        ${m.listState}.failure(failure),\n'
                '      PagedState(items: [], hasReachedEnd: false) =>\n'
                '        const ${m.listState}.loading(),\n'
                '      _ => ${m.listState}.success(page),\n'
                '    };',
              ),
              doc:
                  'No items yet: a failure is the full-page error, anything else is still\n'
                  'loading. With items, or at the end of an empty list, the grid shows the\n'
                  'page (its footer carries a later page\'s failure).',
            ),
            Method(
              Code('Future<void> close()'),
              annotations: [Code('@override')],
              body: Body([
                for (final a in m.listActions)
                  CodeStmt(Code('_${a.event}Guard?.cancel();')),
                CodeStmt(Code('_paging.dispose();')),
                CodeStmt(Code('return super.close();')),
              ]),
            ),
          ],
        ),
      ],
    ),
  );
}

/// A list action's case: the call runs once per guard window, so a double
/// tap leaves the feature once.
String _listActionCase(LdModel m, LdListAction a) =>
    '    case _${pascalCase(a.event)}():\n'
    '${commentLines(m.text('list_action.${a.event}.comment', 'One ${words(a.event)} per tap: a double tap must not run it twice.'), indent: '      ')}'
    '      if (!(_${a.event}Guard?.isActive ?? false)) {\n'
    '        _${a.event}Guard = Timer(${a.event}Guard, () {});\n'
    '${keepRegion('list.${a.event}', '_navigator.${a.calls}();', indent: '        ')}\n'
    '      }\n';

void _previewBloc(EmitContext ctx, LdModel m) {
  final e = m.listEntity;
  String caseName(LdAction a) => '_${pascalCase(a.event)}';
  ctx.library(
    DartLibrary(
      '$_bloc/${snakeCase(m.previewBloc)}.dart',
      decls: [
        ..._events(m.previewEvent, 'What the preview page asks for.', [
          for (final a in m.actions)
            (a.doc, '${a.event}()', caseName(a), const <(String, String)>[]),
        ]),
        ClassDecl(
          m.previewBloc,
          modifiers: 'final',
          superclass: Code('${ref('McBloc')}<${m.previewEvent}, ${ref(e)}>'),
          doc: m.text(
            'preview_bloc.doc',
            "The preview page's bloc. Its state is the ${m.item} the flow state\n"
                'selected (the summary the list loaded: no second request); its actions\n'
                'leave the feature through the navigator, which only blocs call\n'
                '(plan 01 §4.1).',
          ),
          annotations: [Code('@${ref('injectable')}')],
          members: [
            RawMember(
              Code(
                '${m.previewBloc}(\n'
                '  @${ref('factoryParam')} ${ref(e)} ${m.itemCamel},\n'
                '  this._navigator,\n'
                '  ${ref('Monitoring')} monitoring,\n'
                ') : super(${m.itemCamel}, monitoring: monitoring) {\n'
                '  on<${m.previewEvent}>((event, emit) {\n'
                '    switch (event) {\n'
                '${[for (final a in m.actions) '      case ${caseName(a)}():\n${keepRegion('preview.${a.event}', '_navigator.${a.calls}(state.id);', indent: '        ')}'].join('\n')}\n'
                '    }\n'
                '  });\n'
                '}',
              ),
            ),
            RawMember(Code('final ${ref(m.navigator)} _navigator;')),
          ],
        ),
      ],
    ),
  );
}

void _sectionBloc(EmitContext ctx, LdModel m, LdSection s) {
  final e = m.listEntity;
  final id = m.idOf(s.entity)!;
  ctx.library(
    DartLibrary(
      '$_bloc/${s.snake}_bloc.dart',
      imports: [dartAsync],
      parts: ['${s.snake}_bloc.freezed.dart'],
      decls: [
        ..._events(s.event, "What the preview's ${s.words} ask for.", [
          (
            'Loads the ${s.items} (again): the first load, and Retry after a failure.',
            'load()',
            '_Load',
            const [],
          ),
          (
            'A ${s.item} was tapped: hand it over to the app.',
            'open(${ref(id)} id)',
            '_Open',
            [(ref(id), 'id')],
          ),
        ]),
        ClassDecl(
          s.state,
          modifiers: 'sealed',
          mixins: [Code('_\$${s.state}')],
          doc:
              "Tide's state shape: private cases read with `state.when` (R16).",
          annotations: [Code('@${ref('freezed')}')],
          members: [
            RawMember(Code('const factory ${s.state}.loading() = _Loading;')),
            RawMember(
              Code(
                'const factory ${s.state}.success(List<${ref(s.entity)}> ${camelCase(s.items)}) =\n'
                '    _Success;',
              ),
              doc: 'The ${s.items}, in ${s.title} order (perhaps none).',
            ),
            RawMember(
              Code(
                _failureCase(
                  s.state,
                  'The ${s.items} could not be loaded; the preview itself still shows.',
                ),
              ),
            ),
          ],
        ),
        ClassDecl(
          s.bloc,
          modifiers: 'final',
          superclass: Code('${ref('McBloc')}<${s.event}, ${s.state}>'),
          doc: m.text(
            'section.${s.name}.bloc',
            "The preview's ${s.words}: the first ${s.items} of the ${m.item}, each\n"
                "leaving the feature through the navigator's `${s.calls}`, which only blocs\n"
                'call (plan 01 §4.1). Its own bloc, so a failure here never hides the\n'
                'preview.',
          ),
          annotations: [Code('@${ref('injectable')}')],
          members: [
            RawMember(
              Code(
                '${s.bloc}(\n'
                '  @${ref('factoryParam')} ${ref(e)} ${m.itemCamel},\n'
                '  this._repository,\n'
                '  this._navigator,\n'
                '  ${ref('Monitoring')} monitoring,\n'
                ') : _${m.itemCamel} = ${m.itemCamel},\n'
                '    super(const ${s.state}.loading(), monitoring: monitoring) {\n'
                '  on<${s.event}>(_onEvent);\n'
                '  add(const ${s.event}.load());\n'
                '}',
              ),
            ),
            RawMember(
              Code(
                'final ${ref(e)} _${m.itemCamel};\n'
                'final ${ref(m.repository)} _repository;\n'
                'final ${ref(m.navigator)} _navigator;',
              ),
            ),
            RawMember(
              Code('bool _loading = false;'),
              doc:
                  'True while a load is in flight: a second Retry tap does not start a\n'
                  'second request.',
            ),
            RawMember(
              Code(
                'Future<void> _onEvent(\n'
                '  ${s.event} event,\n'
                '  ${ref('Emitter')}<${s.state}> emit,\n'
                ') async {\n'
                '  switch (event) {\n'
                '    case _Load():\n'
                '      if (_loading) {\n'
                '        return;\n'
                '      }\n'
                '      _loading = true;\n'
                '      try {\n'
                '        emit(const ${s.state}.loading());\n'
                '        final result = await _repository.fetch${s.name}(_${m.itemCamel}.id);\n'
                '        emit(\n'
                '          result.fold(\n'
                '            ${s.state}.success,\n'
                '            ${s.state}.failure,\n'
                '          ),\n'
                '        );\n'
                '      } finally {\n'
                '        _loading = false;\n'
                '      }\n'
                '    case _Open(:final id):\n'
                '${keepRegion('section.${s.name}.open', '_navigator.${s.calls}(id);', indent: '      ')}\n'
                '  }\n'
                '}',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
