// The section-detail domain layer: ids, the retrofit API, the repository and
// the analytics vocabulary (managed), plus the model files (entity, DTOs,
// mapper) that the exemplars wrote by hand: those are emitted once, from the
// spec's `entities`, as a starting point (owned afterwards, ADR-0017).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/core/spec/types.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';

const _model = 'lib/src/domain/model';

void emitDomain(EmitContext ctx, ScModel m) {
  for (final id in m.ids) {
    ctx.library(
      DartLibrary(
        '$_model/${id.file}',
        decls: [
          ExtensionTypeDecl(
            id.name,
            Code('${tyName(id.type)} value'),
            doc: id.doc ?? 'An id in this feature\'s own vocabulary.',
          ),
        ],
      ),
    );
  }
  _skeleton(ctx, m);
  ctx.library(_api(m));
  ctx.library(_repository(m));
  if (m.analytics case final a?) ctx.library(_analytics(m, a));
}

// --- the managed files --------------------------------------------------------

DartLibrary _api(ScModel m) {
  final fav = m.favouritePath;
  final item = m.itemWords;
  final extras =
      "{@${ref('Extras')}() Map<String, dynamic> extras = const {},}";
  String path(String p) => p;
  final members = <Member>[
    RawMember(
      Code('factory ${m.api}(${ref('Dio')} dio) = _${m.api};'),
      annotations: [Code('@${ref('factoryMethod')}')],
    ),
    RawMember(
      Code(
        'Future<${ref(m.dto)}> get${m.itemPascal}(@${ref('Path')}(\'id\') ${m.idPrim} id);',
      ),
      doc: m.text(
        'api.get_item',
        'The $item in detail; `404` for an unknown id.',
      ),
      annotations: [Code("@${ref('GET')}('${path(m.itemPath)}')")],
    ),
    if (m.related case final r?)
      RawMember(
        Code(
          'Future<${ref(r.pageDto)}> get${r.pascal}(\n'
          "  @${ref('Query')}('${r.param}') ${m.idPrim} ${r.param},\n"
          "  @${ref('Query')}('limit') int limit,\n"
          ');',
        ),
        doc: m.text(
          'api.get_related',
          'A page of the ${r.name} of the $item, in title order.',
        ),
        annotations: [Code("@${ref('GET')}('${r.path}')")],
      ),
    RawMember(
      Code(
        'Future<${ref('FavouriteDto')}> getFavourite(@${ref('Path')}(\'id\') ${m.idPrim} id);',
      ),
      doc: m.text(
        'api.get_favourite',
        reflow(
          '`200` when the $item is a favourite of the signed-in user, `404` when it is not. Needs the bearer.',
          indent: 2,
        ),
      ),
      annotations: [Code("@${ref('GET')}('$fav')")],
    ),
    for (final (verb, method, text) in [
      (
        'put',
        'PUT',
        'Marks the $item as a favourite (idempotent). Needs the bearer. Pass `authPinned(epoch)` as [extras] to send it only for that session.',
      ),
      (
        'delete',
        'DELETE',
        'Removes the $item from the favourites (idempotent). Needs the bearer. Pass `authPinned(epoch)` as [extras] to send it only for that session.',
      ),
    ])
      RawMember(
        Code(
          'Future<${ref('FavouriteDto')}> ${verb}Favourite(\n'
          "  @${ref('Path')}('id') ${m.idPrim} id, $extras\n"
          ');',
        ),
        doc: m.text('api.${verb}_favourite', reflow(text, indent: 2)),
        annotations: [Code("@${ref(method)}('$fav')")],
      ),
  ];
  return DartLibrary(
    'lib/src/domain/api/${m.module}_api.dart',
    parts: ['${m.module}_api.g.dart'],
    decls: [
      ClassDecl(
        m.api,
        modifiers: 'abstract',
        doc: m.text(
          'api.doc',
          "The feature's own retrofit API on the shared `Dio` (Tide: one per\n"
              'feature). The `Dio` comes from the root container (a `RootImport`), with\n'
              'the auth interceptor on it, so the favourite calls carry the bearer.\n'
              '\n'
              'Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.',
        ),
        annotations: [
          Code('@${ref('injectable')}'),
          Code('@${ref('RestApi')}()'),
        ],
        members: members,
      ),
    ],
  );
}

DartLibrary _repository(ScModel m) {
  final item = m.itemWords;
  final id = ref(m.itemIdType);
  final failure = ref('ApiFailure');
  final result = ref('Result');
  final mapper = use('${m.dto}Mapper');
  final related = m.related;
  final members = <Member>[
    RawMember(Code('const ${m.repository}(this._api);')),
    RawMember(Code('final ${ref(m.api)} _api;')),
    if (related != null)
      RawMember(
        Code('static const int ${related.camel}Limit = ${related.limit};'),
        doc: m.text(
          'repository.related_limit',
          'How many ${related.name} the page asks for.',
        ),
      ),
    RawMember(
      Code(
        'Future<$result<${ref(m.entity)}, $failure>> fetch${m.itemPascal}($id id) =>\n'
        '    ${ref('apiCall')}(() async => (await _api.get${m.itemPascal}(id.value)).toDomain()$mapper);',
      ),
      doc: m.text(
        'repository.fetch_item',
        reflow(
          'The $item in detail. An unknown $item is [ApiNotFound].',
          indent: 2,
        ),
      ),
    ),
    if (related != null)
      RawMember(
        Code(
          'Future<$result<List<${ref(related.summary)}>, $failure>> fetch${related.pascal}($id id) =>\n'
          '    ${ref('apiCall')}(() async {\n'
          '      final page = await _api.get${related.pascal}(id.value, ${related.camel}Limit);\n'
          '      return [for (final ${related.item} in page.results) ${related.item}.toDomain()];\n'
          '    });',
        ),
        doc: m.text(
          'repository.fetch_related',
          'The ${related.name} of the $item, in title order (at most\n'
              '[${related.camel}Limit]).',
        ),
      ),
    RawMember(
      Code(
        'Future<$result<bool, $failure>> isFavourite($id id) => ${ref('apiCall')}(\n'
        '  () async =>\n'
        '      await _orNullWhenNotFound(\n'
        '        () async => (await _api.getFavourite(id.value)).favourite,\n'
        '      ) ??\n'
        '      false,\n'
        ');',
      ),
      doc: m.text(
        'repository.is_favourite',
        reflow(
          'Whether the signed-in user has the $item among their favourites. The backend answers `404` for "not a favourite".',
          indent: 2,
        ),
      ),
    ),
    RawMember(
      Code(
        'Future<$result<bool, $failure>> setFavourite(\n'
        '  $id id, {\n'
        '  required bool favourite,\n'
        '  required int epoch,\n'
        '}) => ${ref('apiCall')}(\n'
        '  () async => (favourite\n'
        '          ? await _api.putFavourite(id.value, extras: ${ref('authPinned')}(epoch))\n'
        '          : await _api.deleteFavourite(id.value, extras: ${ref('authPinned')}(epoch)))\n'
        '      .favourite,\n'
        ');',
      ),
      doc: m.text(
        'repository.set_favourite',
        'Writes the flag and returns what the backend now holds. The request is\n'
            'pinned to the session [epoch] the caller\'s own check used (the session its\n'
            'shown state belongs to): if the session changed\n'
            'before it was sent, nothing is sent and the answer is\n'
            '[ApiUnauthorized] (T-0050), so a write never goes out under another\n'
            'user\'s bearer.',
      ),
    ),
    RawMember(
      Code(
        'static Future<T?> _orNullWhenNotFound<T extends Object>(\n'
        '  Future<T> Function() call,\n'
        ') async {\n'
        '  try {\n'
        '    return await call();\n'
        '  } on ${ref('DioException')} catch (e) {\n'
        '    if (e.response?.statusCode == 404) {\n'
        '      return null;\n'
        '    }\n'
        '    rethrow;\n'
        '  }\n'
        '}',
      ),
    ),
  ];
  return DartLibrary(
    'lib/src/domain/repository/${m.module}_repository.dart',
    decls: [
      ClassDecl(
        m.repository,
        doc: m.text(
          'repository.doc',
          'The $item and its favourite flag as values, never exceptions. Stateless\n'
              '(Tide): what the page shows lives in its blocs and the flow state.',
        ),
        annotations: [Code('@${ref('injectable')}')],
        members: members,
      ),
    ],
  );
}

DartLibrary _analytics(ScModel m, ScAnalytics a) => DartLibrary(
  'lib/src/domain/model/${snakeCase(m.item)}_analytics.dart',
  decls: [
    RawDecl(
      Code("const String ${a.screenConst} = '${a.screen}';"),
      name: a.screenConst,
      doc: m.text(
        'analytics.screen',
        "The screen name of the flow's one page: its `McFlowPage` name, which\n"
            '`AnalyticsFlowObserver` tracks (ADR-0012).',
      ),
    ),
    RawDecl(
      Code("const String ${a.eventConst} = '${a.event}';"),
      name: a.eventConst,
      doc: m.text(
        'analytics.event',
        'The signed-in user saved the ${m.itemWords} among their favourites.',
      ),
    ),
    ExtensionDeclFix.of(
      name: a.extension,
      on: ref('AnalyticsTracker'),
      doc: m.text(
        'analytics.extension',
        'The page\'s analytics vocabulary over the blocs\' pure-Dart port\n'
            '(`AnalyticsTracker`, R15, ADR-0012): the event and its parameters are\n'
            'spelled once, here.',
      ),
      member:
          'void ${a.method}(${ref(m.itemIdType)} id) =>\n'
          "    trackEvent(${a.eventConst}, {'id': id.value});",
      memberDoc: m.text(
        'analytics.method',
        '`${a.event}` with `id`, the ${m.itemWords}\'s id. Only a saved favourite\n'
            'counts: not a removal, a failed write or a sign-in that was backed out\n'
            'of.',
      ),
    ),
  ],
);

/// An extension with one documented member, as a [RawDecl].
class ExtensionDeclFix {
  static RawDecl of({
    required String name,
    required String on,
    required String doc,
    required String member,
    required String memberDoc,
  }) => RawDecl(
    Code(
      'extension $name on $on {\n${docLines(memberDoc, indent: '  ')}  $member\n}',
    ),
    name: name,
    doc: doc,
  );
}

// --- the owned skeleton ---------------------------------------------------------

/// The model files the exemplars wrote by hand: the entity (and the other
/// domain entities of the spec), the DTOs and the mapper. They are emitted
/// once and owned from then on; what they need is only what the managed files
/// reference: the entity, its DTO, `FavouriteDto`, the related summary and
/// its page DTO, and a `toDomain` for each DTO.
void _skeleton(EmitContext ctx, ScModel m) {
  final spec = m.spec;
  final domain = [
    for (final e in spec.entities)
      if (e.json != true) e,
  ];
  final dtos = [
    for (final e in spec.entities)
      if (e.json == true) e,
  ];
  if (!spec.entities.any((e) => e.name == m.entity)) {
    throw StateError('${spec.file}: no entity "${m.entity}" in entities');
  }
  final idTypes = {for (final i in m.ids) i.name: i};
  String param(FieldSpec f) {
    final prefix = needsRequired(f) ? 'required ' : '';
    return '$prefix${ty(f.type)} ${f.name},';
  }

  ctx.library(
    DartLibrary(
      '$_model/${m.entityFile}',
      parts: ['${snakeCase(m.entity)}.freezed.dart'],
      decls: [
        for (final e in domain)
          ClassDecl(
            e.name,
            modifiers: 'abstract',
            mixins: [Code('_\$${e.name}')],
            doc: e.doc,
            annotations: [Code('@${ref('freezed')}')],
            members: [
              RawMember(
                Code(
                  'const factory ${e.name}({\n'
                  '${[for (final f in e.fields) param(f)].join('\n')}\n'
                  '}) = _${e.name};',
                ),
              ),
            ],
          ),
      ],
    ),
    owned: true,
  );
  final dtoNames = {for (final d in dtos) d.name};
  ctx.library(
    DartLibrary(
      '$_model/${m.dtoFile}',
      parts: [
        '${snakeCase(m.entity)}_dto.freezed.dart',
        '${snakeCase(m.entity)}_dto.g.dart',
      ],
      decls: [
        for (final d in dtos)
          ClassDecl(
            d.name,
            modifiers: 'abstract',
            mixins: [Code('_\$${d.name}')],
            doc: d.doc,
            annotations: [
              Code('@${ref('Freezed')}(fromJson: true, toJson: true)'),
            ],
            members: [
              RawMember(
                Code(
                  'const factory ${d.name}({\n'
                  '${[for (final f in d.fields) param(f)].join('\n')}\n'
                  '}) = _${d.name};',
                ),
                annotations: [
                  if (d.fields.any((f) => f.type.names.any(dtoNames.contains)))
                    Code('@${ref('JsonSerializable')}(explicitToJson: true)'),
                ],
              ),
              RawMember(
                Code(
                  'factory ${d.name}.fromJson(Map<String, dynamic> json) =>\n'
                  '    _\$${d.name}FromJson(json);',
                ),
              ),
            ],
          ),
        ClassDecl(
          'FavouriteDto',
          modifiers: 'abstract',
          mixins: [Code('_\$FavouriteDto')],
          doc:
              '`GET/PUT/DELETE ${m.favouritePath.replaceFirst('{id}', ':id')}`: the answer of a\n'
              'favourite read or write.',
          annotations: [
            Code('@${ref('Freezed')}(fromJson: true, toJson: true)'),
          ],
          members: [
            RawMember(
              Code(
                'const factory FavouriteDto({\n'
                '  required String kind,\n'
                '  required String id,\n'
                '  required bool favourite,\n'
                '}) = _FavouriteDto;',
              ),
            ),
            RawMember(
              Code(
                'factory FavouriteDto.fromJson(Map<String, dynamic> json) =>\n'
                '    _\$FavouriteDtoFromJson(json);',
              ),
            ),
          ],
        ),
      ],
    ),
    owned: true,
  );
  // One mapper per DTO whose name is a domain entity's plus `Dto`: the same
  // field names, an id wrapped in its id type, a nested DTO converted.
  // The expression turning DTO field [f] (same name) into the domain field:
  // an id is wrapped in its id type, a nested DTO converted with its own
  // `toDomain`, a list element by element; a nullable one is null-checked.
  final domainNames = {for (final e in domain) e.name};
  String one(TypeExpr t, String v) {
    if (idTypes.containsKey(t.name)) return '${ref(t.name)}($v)';
    if (domainNames.contains(t.name) && dtoNames.contains('${t.name}Dto')) {
      return '$v.toDomain()';
    }
    return v;
  }

  String convert(FieldSpec f) {
    final t = f.type;
    final isList = t.name == 'List' && t.args.length == 1;
    final inner = isList ? t.args.single : t;
    final needs = one(inner, 'e') != 'e';
    final v = f.name;
    if (!needs) return v;
    final nn = t.nullable ? '$v!' : v;
    final value = isList
        ? '[for (final e in $nn) ${one(inner, 'e')}]'
        : one(inner, nn);
    return t.nullable ? '$v == null ? null : $value' : value;
  }

  final decls = <Decl>[];
  for (final d in dtos) {
    final target = domain.where((e) => '${e.name}Dto' == d.name).firstOrNull;
    if (target == null) continue;
    final args = [
      for (final f in target.fields) '${f.name}: ${convert(f)}',
    ];
    decls.add(
      RawDecl(
        Code(
          'extension ${d.name}Mapper on ${ref(d.name)} {\n'
          '  ${ref(target.name)} toDomain() =>\n'
          '      ${ref(target.name)}(${args.join(', ')});\n'
          '}',
        ),
        name: '${d.name}Mapper',
      ),
    );
  }
  ctx.library(
    DartLibrary('$_model/${m.mapperFile}', decls: decls),
    owned: true,
  );
}
