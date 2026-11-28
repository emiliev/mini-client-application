// The section-detail blocs (Tide 5.8: hand-style sealed events with private
// cases, freezed `sealed` states with private cases, monitoring in
// `McBloc`): the details bloc, which loads the entity and hands targets over
// to the app, and the favourite toggle's bloc.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/favourite_templates.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';

const _bloc = 'lib/src/presentation/bloc';

/// [raw] with the lines of the [flags] kept (their `[flag] ` prefix removed)
/// and every other flagged line dropped.
String flagged(String raw, Set<String> flags) {
  final out = <String>[];
  for (final line in raw.split('\n')) {
    final match = RegExp(r'^\[(!?)(\w+)\]').firstMatch(line);
    if (match == null) {
      out.add(line);
      continue;
    }
    final on = flags.contains(match[2]);
    if (on != (match[1] == '!')) out.add(line.substring(match[0]!.length));
  }
  return out.join('\n');
}

void emitBlocs(EmitContext ctx, ScModel m) {
  _detailsBloc(ctx, m);
  _favouriteBloc(ctx, m);
}

// --- details --------------------------------------------------------------------

void _detailsBloc(EmitContext ctx, ScModel m) {
  final item = m.itemCamel;
  final related = m.related;
  final cover = m.cover;
  final multi = m.opens.length > 1;
  final base = '${m.itemCamel}_details';
  final stateCls = m.detailsState;
  final eventCls = m.detailsEvent;
  final bloc = m.detailsBloc;
  final labels = [for (final o in m.opens) o.label];

  // events
  final cases = <(String?, String, String, List<(String, String)>)>[
    (
      m.text(
        'details_event.load',
        'Loads the $item (again): the first load, and Retry after a failure.',
      ),
      'load()',
      '_Load',
      const [],
    ),
    if (cover != null)
      (
        m.text(
          'details_event.${cover.event}',
          'The ${cover.field} was tapped: it opens full size inside the flow.',
        ),
        '${cover.event}()',
        '_${pascalOf(cover.event)}',
        const [],
      ),
    for (final o in m.opens)
      (
        o.eventDoc,
        '${o.calls}(${ref(o.id)} id)',
        '_${o.pascal}',
        [(ref(o.id), 'id')],
      ),
  ];
  ctx.library(
    DartLibrary(
      '$_bloc/${base}_event.dart',
      partOf: '${base}_bloc.dart',
      decls: [
        RawDecl(
          Code(_eventsText(eventCls, cases)),
          name: eventCls,
          doc: m.text(
            'details_event.doc',
            'What the details page asks for. Hand-written sealed events with private\n'
                'cases (Tide), so a page can only create them through the factories.',
          ),
        ),
      ],
    ),
  );

  // state
  final success = related == null
      ? 'const factory $stateCls.success(${ref(m.entity)} $item) = _Success;'
      : 'const factory $stateCls.success(\n'
            '  ${ref(m.entity)} $item,\n'
            '  List<${ref(related.summary)}> ${related.camel},\n'
            ') = _Success;';
  ctx.library(
    DartLibrary(
      '$_bloc/${base}_state.dart',
      partOf: '${base}_bloc.dart',
      decls: [
        ClassDecl(
          stateCls,
          modifiers: 'sealed',
          mixins: [Code('_\$$stateCls')],
          doc:
              "Tide's state shape: private cases read with `state.when` (R16); freezed 4\n"
              'adds only `sealed`.',
          annotations: [Code('@${ref('freezed')}')],
          members: [
            RawMember(
              Code('const factory $stateCls.loading() = _Loading;'),
              doc: m.text(
                'details_state.loading',
                'The $item is on its way.',
              ),
            ),
            RawMember(
              Code(success),
              doc: m.text('details_state.success', 'The $item.'),
            ),
            RawMember(
              Code('const factory $stateCls.notFound() = _NotFound;'),
              doc: m.text(
                'details_state.not_found',
                reflow(
                  'No $item has this id (`404`). Not a failure: nothing to retry or report.',
                  indent: 2,
                ),
              ),
            ),
            RawMember(
              Code(
                '@${ref('Implements')}<${ref('McFailureState')}>()\n'
                'const factory $stateCls.failure(\n'
                '  ${ref('ApiFailure')} error, {\n'
                '  StackTrace? stackTrace,\n'
                '}) = _Failure;',
              ),
              doc: m.text(
                'details_state.failure',
                reflow(
                  'The $item could not be loaded. `McBloc` reports it to monitoring (D-16).',
                  indent: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // the bloc
  final guardType = multi ? '(String, int)' : ref(m.opens.single.id);
  final loadBody = related == null
      ? '          final result = await _repository.fetch${m.itemPascal}(_flow.state.${m.idArg});\n'
            '          emit(\n'
            '            result.fold(\n'
            '              $stateCls.success,\n'
            '              (failure) => failure is ${ref('ApiNotFound')}\n'
            '                  ? const $stateCls.notFound()\n'
            '                  : $stateCls.failure(failure),\n'
            '            ),\n'
            '          );\n'
      : '          final id = _flow.state.${m.idArg};\n'
            '${commentLines(m.text('details_bloc.load_comment', 'Both requests start at once: the page does not wait for the ${related.name}\nto ask for them.'), indent: '          ')}'
            '          final ($item, ${related.camel}) = await (\n'
            '            _repository.fetch${m.itemPascal}(id),\n'
            '            _repository.fetch${related.pascal}(id),\n'
            '          ).wait;\n'
            '          emit(_stateOf($item, ${related.camel}));\n';
  final coverCase = cover == null
      ? ''
      : '      case _${pascalOf(cover.event)}():\n'
            '${commentLines(m.text('details_bloc.cover_comment', 'One ${cover.field} page at a time, and only for a loaded $item.'), indent: '        ')}'
            '        if (state case _Success(:final $item) when _flow.state.${cover.field} == null) {\n'
            '          _flow.update((s) => s.copyWith(${cover.field}: $item));\n'
            '        }\n';
  final openCases = [
    for (final o in m.opens)
      '      case _${o.pascal}(:final id):\n'
          '        if (_startOpenGuard(${multi ? "('${o.label}', id.value)" : 'id'})) {\n'
          '${keepRegion('details.${o.calls}', '_navigator.${o.calls}(id);', indent: '          ')}\n'
          '        }\n',
  ].join();
  final stateOf = related == null
      ? ''
      : '\n\n'
            '${docLines(m.text('details_bloc.state_of', reflow('The $item decides first: an unknown one is not found whatever the ${related.name} said; any other failure of either request fails the page, and Retry reloads both.', indent: 2)), indent: '  ')}'
            '  $stateCls _stateOf(\n'
            '    ${ref('Result')}<${ref(m.entity)}, ${ref('ApiFailure')}> $item,\n'
            '    ${ref('Result')}<List<${ref(related.summary)}>, ${ref('ApiFailure')}> ${related.camel},\n'
            '  ) => $item.fold(\n'
            '    (profile) => ${related.camel}.fold(\n'
            '      (list) => $stateCls.success(profile, list),\n'
            '      $stateCls.failure,\n'
            '    ),\n'
            '    (failure) => failure is ${ref('ApiNotFound')}\n'
            '        ? const $stateCls.notFound()\n'
            '        : $stateCls.failure(failure),\n'
            '  );';
  final members = <Member>[
    RawMember(
      Code(
        '$bloc(\n'
        '  this._repository,\n'
        '  this._flow,\n'
        '  this._navigator,\n'
        '  ${ref('Monitoring')} monitoring,\n'
        ') : super(const $stateCls.loading(), monitoring: monitoring) {\n'
        '  on<$eventCls>(_onEvent);\n'
        '  add(const $eventCls.load());\n'
        '}',
      ),
    ),
    RawMember(
      Code(
        'final ${ref(m.repository)} _repository;\n'
        'final ${ref('FeatureFlowController')}<${ref(m.flowState)}> _flow;\n'
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
      Code('Timer? _openGuard;'),
      doc: m.text(
        'details_bloc.guard_timer',
        'Runs for [openGuard] after ${_anyOf(labels)} was handed over.',
      ),
    ),
    RawMember(
      Code('$guardType? _openTarget;'),
      doc: 'What the running guard was started for.',
    ),
    RawMember(
      Code(
        'Future<void> _onEvent(\n'
        '  $eventCls event,\n'
        '  ${ref('Emitter')}<$stateCls> emit,\n'
        ') async {\n'
        '  switch (event) {\n'
        '    case _Load():\n'
        '      if (_loading) {\n'
        '        return;\n'
        '      }\n'
        '      _loading = true;\n'
        '      try {\n'
        '        emit(const $stateCls.loading());\n'
        '${loadBody.split('\n').map((l) => l.isEmpty ? l : l.substring(2)).join('\n')}'
        '      } finally {\n'
        '        _loading = false;\n'
        '      }\n'
        '${coverCase.split('\n').map((l) => l.isEmpty ? l : l.substring(2)).join('\n')}'
        '${openCases.split('\n').map((l) => l.isEmpty ? l : l.substring(2)).join('\n')}'
        '  }\n'
        '}$stateOf',
      ),
    ),
    RawMember(
      Code(
        'bool _startOpenGuard($guardType target) {\n'
        '  if ((_openGuard?.isActive ?? false) && _openTarget == target) {\n'
        '    return false;\n'
        '  }\n'
        '  _openGuard?.cancel();\n'
        '  _openGuard = Timer(openGuard, () {});\n'
        '  _openTarget = target;\n'
        '  return true;\n'
        '}',
      ),
      doc: m.text(
        'details_bloc.start_guard',
        reflow(
          'False while a hand-over of the same [target] still guards (the second tap of a double tap); else starts the guard for it. A different target goes through at once: popping back and tapping something else within [openGuard] is not a double tap.',
          indent: 2,
        ),
      ),
    ),
    RawMember(
      Code(
        'Future<void> close() {\n'
        '  _openGuard?.cancel();\n'
        '  return super.close();\n'
        '}',
      ),
      annotations: [Code('@override')],
    ),
  ];
  ctx.library(
    DartLibrary(
      '$_bloc/${base}_bloc.dart',
      imports: [dartAsync],
      parts: [
        '${base}_bloc.freezed.dart',
        '${base}_event.dart',
        '${base}_state.dart',
      ],
      decls: [
        RawDecl(
          Code('const Duration openGuard = Duration(milliseconds: 500);'),
          name: 'openGuard',
          doc: m.text(
            'details_bloc.open_guard',
            reflow(
              'How long after handing ${_anyOf(labels)} over a second hand-over of the same one is ignored: the second tap of a double tap (P-089). By then the opened page covers this one. The same value as `discovery_search`\'s open guard.',
            ),
          ),
        ),
        ClassDecl(
          bloc,
          modifiers: 'final',
          superclass: Code('${ref('McBloc')}<$eventCls, $stateCls>'),
          doc: m.text(
            'details_bloc.doc',
            "The details page's bloc: loads the $item, and hands a tapped target over to\n"
                'the app through the navigator, which only blocs call (plan 01 §4.1). A second\n'
                'hand-over of the same target within [openGuard] is ignored, so a double tap\n'
                'opens one page.\n'
                '\n'
                'Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never\n'
                'Flutter, so every generator that reads it runs on analyzer summaries.',
          ),
          annotations: [Code('@${ref('injectable')}')],
          members: members,
        ),
      ],
    ),
  );
}

String pascalOf(String camel) => camel[0].toUpperCase() + camel.substring(1);

String _anyOf(List<String> labels) => switch (labels.length) {
  0 => 'a target',
  1 => 'a ${labels.single}',
  2 => 'a ${labels[0]} or ${labels[1]}',
  _ =>
    '${[for (final l in labels.take(labels.length - 1)) 'a $l'].join(', ')} or a ${labels.last}',
};

/// A sealed event class with private cases: [cases] are (factory doc,
/// factory signature, case class, fields).
String _eventsText(
  String name,
  List<(String?, String, String, List<(String, String)>)> cases,
) {
  final b = StringBuffer()
    ..writeln('sealed class $name {')
    ..writeln('  const $name();');
  for (final (doc, factory, c, _) in cases) {
    b
      ..writeln()
      ..write(docLines(doc, indent: '  '))
      ..writeln('  const factory $name.$factory = $c;');
  }
  b.writeln('}');
  for (final (_, _, c, fields) in cases) {
    b
      ..writeln()
      ..writeln('final class $c extends $name {')
      ..writeln(
        '  const $c(${[for (final f in fields) 'this.${f.$2}'].join(', ')});',
      );
    if (fields.isNotEmpty) {
      b.writeln();
      for (final f in fields) {
        b.writeln('  final ${f.$1} ${f.$2};');
      }
    }
    b.writeln('}');
  }
  return b.toString().trimRight();
}

// --- the favourite toggle's bloc ------------------------------------------------

void _favouriteBloc(EmitContext ctx, ScModel m) {
  final a = m.analytics;
  final flags = {if (a != null) 'analytics'};
  final vars = {
    'Item': m.itemPascal,
    'item': m.item,
    'itemCamel': m.itemCamel,
    'Prefix': m.prefix,
    'prefixCamel': m.prefixCamel,
    'Navigator': m.navigator,
    'IdType': m.itemIdType,
    'idArg': m.idArg,
    'module': m.module,
    'analyticsMethod': a?.method ?? '',
    'analyticsExt': a?.extension ?? 'Object',
    'analyticsEvent': a?.event ?? '',
  };
  String t(String raw) => tpl(flagged(raw, flags), vars).trimRight();
  final base = '${m.item}_favourite';
  final bloc = m.favouriteBloc;
  final signal = a == null
      ? 'Every saved write publishes `DataChanged(\'favourites\')` once, and a '
            '`DataChanged(\'favourites\')` from anyone else (another page of the same ${m.item}) reads the flag again.'
      : 'Every saved write publishes `DataChanged(\'favourites\')` once, a saved '
            'favourite (not a removal) tracks `${a.event}`, and a '
            '`DataChanged(\'favourites\')` from anyone else (another page of the same ${m.item}) reads the flag again.';
  final doc = m.text(
    'favourite_bloc.doc',
    "The favourite toggle's bloc.\n"
        '\n'
        '- **Signed out:** a tap means "add it". It asks the app to sign in and\n'
        '  waits (`requestSignIn()`). On false nothing changes and no request is\n'
        '  made. On true it first reads the flag for the new session: if that user\n'
        '  already has the ${m.item}, nothing is written; otherwise it is saved.\n'
        '- **Signed in:** a tap flips the toggle at once (optimistic), then writes;\n'
        '  a failed write flips it back and shows an inline error.\n'
        '- **One at a time:** a tap while a sign-in or a write is in flight is\n'
        '  ignored, so a double tap sends one request.\n'
        '- **The session decides:** it follows `SessionReader.authState`. A\n'
        '  sign-in elsewhere reloads the flag for that user; a sign-out (a rejected\n'
        '  refresh included) shows "not a favourite". A change during a tap is\n'
        '  applied when the tap settles.\n'
        '\n'
        '${reflow(signal)}',
  );
  ctx.library(
    DartLibrary(
      '$_bloc/${base}_bloc.dart',
      imports: [dartAsync],
      parts: [
        '${base}_bloc.freezed.dart',
        '${base}_event.dart',
        '${base}_state.dart',
      ],
      decls: [
        RawDecl(
          Code(t(favouriteTopicTemplate.split('\n').skip(2).join('\n'))),
          name: 'favouritesTopic',
          doc: m.text(
            'favourite_bloc.topic',
            'The `mc_event_bus` topic a favourite write announces (P1-18 AC6), so\n'
                'whatever lists favourites refreshes.',
          ),
        ),
        RawDecl(Code(t(favouriteBlocTemplate)), name: bloc, doc: doc),
      ],
    ),
  );
  ctx.library(
    DartLibrary(
      '$_bloc/${base}_event.dart',
      partOf: '${base}_bloc.dart',
      decls: [
        RawDecl(
          Code(t(favouriteEventTemplate)),
          name: m.favouriteEvent,
          doc: 'What the favourite toggle asks for.',
        ),
      ],
    ),
  );
  ctx.library(
    DartLibrary(
      '$_bloc/${base}_state.dart',
      partOf: '${base}_bloc.dart',
      decls: [
        RawDecl(
          Code(t(favouriteStateTemplate)),
          name: m.favouriteState,
          doc:
              "Tide's state shape: private cases read with `state.when` (R16).",
        ),
      ],
    ),
  );
}
