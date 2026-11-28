// The list-detail domain layer: ids, models, DTOs, mappers, the list query,
// the retrofit API and the repository (plan 02 section 2.3, Tide 5.5-5.7).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

const _model = 'lib/src/domain/model';

void emitDomain(EmitContext ctx, LdModel m) {
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
  for (final e in m.domainEntities) {
    ctx.library(
      DartLibrary(
        '$_model/${snakeCase(e.name)}.dart',
        parts: ['${snakeCase(e.name)}.freezed.dart'],
        decls: [_domainModel(e)],
      ),
    );
  }
  ctx.library(
    DartLibrary(
      '$_model/${m.dtoFile}',
      parts: [
        '${m.dtoFile.replaceFirst('.dart', '.freezed.dart')}',
        '${m.dtoFile.replaceFirst('.dart', '.g.dart')}',
      ],
      decls: [for (final d in m.dtos) _dto(m, d)],
    ),
  );
  ctx.library(_mappers(m));
  ctx.library(_query(m));
  ctx.library(_api(m));
  ctx.library(_repository(m));
}

String _param(FieldSpec f) {
  final prefix = needsRequired(f) ? 'required ' : '';
  final suffix = f.hasDefault ? ' = ${literal(f.defaultValue)}' : '';
  return '$prefix${ty(f.type)} ${f.name}$suffix,';
}

ClassDecl _domainModel(EntitySpec e) => ClassDecl(
  e.name,
  modifiers: 'abstract',
  mixins: [Code('_\$${e.name}')],
  doc: e.doc,
  annotations: [Code('@${ref('freezed')}')],
  members: [
    RawMember(
      Code(
        'const factory ${e.name}({\n'
        '${documented([for (final f in e.fields) (f.doc, _param(f))])}\n'
        '}) = _${e.name};',
      ),
    ),
  ],
);

ClassDecl _dto(LdModel m, EntitySpec d) {
  final dtoNames = {for (final x in m.dtos) x.name};
  final nested = d.fields.any((f) => f.type.names.any(dtoNames.contains));
  final params = [for (final f in d.fields) (f.doc, _param(f))];
  // One line when it fits: the formatter joins an unsplit list, and keeps a
  // split one only when it ends in a comma.
  final inline = params.every((p) => p.$1 == null);
  final list = inline
      ? params.map((p) => p.$2).join(' ').replaceFirst(RegExp(r',$'), '')
      : documented(params);
  return ClassDecl(
    d.name,
    modifiers: 'abstract',
    mixins: [Code('_\$${d.name}')],
    doc: d.doc,
    annotations: [Code('@${ref('Freezed')}(fromJson: true, toJson: true)')],
    members: [
      RawMember(
        Code(
          'const factory ${d.name}({${inline ? '' : '\n'}$list${inline ? '' : '\n'}}) = _${d.name};',
        ),
        annotations: [
          if (nested) Code('@${ref('JsonSerializable')}(explicitToJson: true)'),
        ],
      ),
      RawMember(
        Code(
          'factory ${d.name}.fromJson(Map<String, dynamic> json) =>\n'
          '    _\$${d.name}FromJson(json);',
        ),
      ),
    ],
  );
}

/// The expression converting DTO field [dtoField] of [x] for domain field
/// [domain] (null: an external target, which takes the DTO's own fields).
String _convert(LdModel m, LdMapper x, String dtoField, FieldSpec? domain) {
  final dto = m.entity(x.dto);
  final source = dto.fields.firstWhere(
    (f) => f.name == dtoField,
    orElse: () => throw StateError(
      'mapper ${x.dto} -> ${x.to}: ${x.dto} has no field "$dtoField"',
    ),
  );
  final via = x.via[dtoField];
  if (via != null) {
    final dot = via.indexOf('.');
    final head = dot < 0 ? via : via.substring(0, dot);
    final tail = dot < 0 ? '' : via.substring(dot);
    return '${ref(head)}$tail($dtoField)';
  }
  if (domain != null &&
      m.ids.any((i) => i.name == domain.type.name) &&
      m.ids.firstWhere((i) => i.name == domain.type.name).type ==
          source.type.name) {
    return '${ref(domain.type.name)}($dtoField)';
  }
  if (m.dtos.any((d) => d.name == source.type.name)) {
    return '$dtoField.toDomain()';
  }
  return dtoField;
}

DartLibrary _mappers(LdModel m) {
  final decls = <Decl>[];
  for (final (i, x) in m.mappers.indexed) {
    final target = m.spec.entities.where((e) => e.name == x.to).firstOrNull;
    final args = <String>[];
    if (target != null) {
      for (final f in target.fields) {
        args.add('${f.name}: ${_convert(m, x, x.fields[f.name] ?? f.name, f)}');
      }
    } else {
      for (final f in m.entity(x.dto).fields) {
        final to = x.fields.entries
            .firstWhere(
              (e) => e.value == f.name,
              orElse: () => MapEntry(f.name, f.name),
            )
            .key;
        args.add('$to: ${_convert(m, x, f.name, null)}');
      }
    }
    final name = '${x.dto}Mapper';
    decls.add(
      RawDecl(
        Code(
          'extension $name on ${ref(x.dto)} {\n'
          '  ${ref(x.to)} toDomain() =>\n'
          '      ${ref(x.to)}(${args.join(', ')});\n'
          '}',
        ),
        name: name,
        doc: i == 0 ? m.text('mapper.doc', 'Wire to domain.') : null,
      ),
    );
  }
  final listDto = m.mappers.firstWhere((x) => x.to == m.listEntity).dto;
  final pageMapper = '${m.listEntity}PageMapper';
  decls.add(
    RawDecl(
      Code(
        'extension $pageMapper on ${ref('ApiPage')}<${ref(listDto)}> {\n'
        '  ${ref('Page')}<${ref(m.listEntity)}> toDomain() => ${ref('Page')}(\n'
        '    offset: offset,\n'
        '    limit: limit,\n'
        '    total: total,\n'
        '    results: [for (final dto in results) dto.toDomain()],\n'
        '  );\n'
        '}',
      ),
      name: pageMapper,
      doc: "The envelope as the paging kit's [Page].",
    ),
  );
  return DartLibrary('$_model/${m.mapperFile}', decls: decls);
}

DartLibrary _query(LdModel m) {
  final params = [
    'required this.offset,',
    'required this.limit,',
    for (final f in m.filters) 'this.${f.name},',
  ];
  final fields = [
    (null, 'final int offset;'),
    (null, 'final int limit;'),
    for (final f in m.filters) (f.queryDoc, 'final ${ty(f.type)} ${f.name};'),
  ];
  return DartLibrary(
    '$_model/${m.queryFile}',
    decls: [
      ClassDecl(
        m.query,
        modifiers: 'final',
        doc: m.text(
          'query.doc',
          'What the list asks the backend for: one page.',
        ),
        members: [
          RawMember(Code('const ${m.query}({${params.join(' ')}});')),
          RawMember(Code(documented(fields))),
        ],
      ),
    ],
  );
}

String _queryParam(QueryParamSpec q) {
  final type = q.type == null ? 'String?' : ty(q.type!);
  final required = q.required ? 'required ' : '';
  final value = q.hasDefault ? ' = ${literal(q.defaultValue)}' : '';
  return "@${ref('Query')}('${q.name}') $required$type ${q.name}$value,";
}

DartLibrary _api(LdModel m) {
  final methods = <Member>[
    RawMember(
      Code('factory ${m.api}(${ref('Dio')} dio) = _${m.api};'),
      annotations: [Code('@${ref('factoryMethod')}')],
    ),
    for (final e in m.spec.endpoints)
      RawMember(
        Code(
          'Future<${ty(e.returns!)}> ${e.id}(${e.params.isEmpty ? '' : '{${e.params.map(_queryParam).join(' ')}}'});',
        ),
        doc: e.doc,
        annotations: [
          Code("@${ref(e.method)}('${e.urlPath}')"),
        ],
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
              'feature). The `Dio` comes from the root container (a `RootImport`).\n'
              '\n'
              'Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.',
        ),
        annotations: [
          Code('@${ref('injectable')}'),
          Code('@${ref('RestApi')}()'),
        ],
        members: methods,
      ),
    ],
  );
}

DartLibrary _repository(LdModel m) {
  final list = m.endpoint(m.listEndpoint);
  final args = [
    for (final q in list.params)
      if (q.name == 'offset')
        'offset: q.offset,'
      else if (q.name == 'limit')
        'limit: q.limit,'
      else
        for (final f in m.filters)
          if (f.query == q.name) '${q.name}: q.${f.name},',
  ];
  final members = <Member>[
    RawMember(Code('const ${m.repository}(this._api);')),
    RawMember(Code('final ${ref(m.api)} _api;')),
    RawMember(
      Code(
        'Future<${ref('Result')}<${ref('Page')}<${ref(m.listEntity)}>, ${ref('ApiFailure')}>> fetchPage(${ref(m.query)} q) =>\n'
        '    ${ref('apiCall')}(\n'
        '      () async => (await _api.${list.id}(${args.join(' ')})).toDomain()${use('${m.listEntity}PageMapper')},\n'
        '    );',
      ),
    ),
    for (final s in m.sections)
      RawMember(
        Code(
          'Future<${ref('Result')}<List<${ref(s.entity)}>, ${ref('ApiFailure')}>> fetch${s.name}(\n'
          '  ${ref(m.listEntityId)} ${m.itemCamel}, {\n'
          '  int limit = ${s.camel}Limit,\n'
          '}) => ${ref('apiCall')}(\n'
          '  () async => [\n'
          '    for (final dto in (await _api.${s.endpoint}(\n'
          '      ${s.by}: ${m.itemCamel}.value,\n'
          '      limit: limit,\n'
          '    )).results)\n'
          '      dto.toDomain()${use('${m.mappers.firstWhere((x) => x.to == s.entity).dto}Mapper')},\n'
          '  ],\n'
          ');',
        ),
        doc: m.text(
          'repository.fetch${s.name}',
          'The first [limit] ${s.items} of [${m.itemCamel}].',
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
          'Pages of ${m.items} as values, never exceptions. Stateless (Tide): what\n'
              'the user selected lives in the flow state, not here.',
        ),
        annotations: [Code('@${ref('injectable')}')],
        members: members,
      ),
      for (final s in m.sections)
        RawDecl(
          Code('const int ${s.camel}Limit = ${s.limit};'),
          name: '${s.camel}Limit',
          doc: 'How many ${s.words} the preview lists.',
        ),
    ],
  );
}
