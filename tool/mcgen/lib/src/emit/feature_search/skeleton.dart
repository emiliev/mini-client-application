// The module's own files, written once for a new paged module
// (`options.skeleton`, ADR-0017): the domain (API, DTOs, mapper, facets,
// repository), the results widgets, the test env, the contract and
// flow-scope tests, and BUILD.bazel. All are owned from the first write: an
// exemplar writes its own and sets no skeleton.
//
// The skeleton is a working search over one endpoint with one enum facet
// (`sort`): enough to run the managed bloc, page and steps end to end, and
// the shape a module's hand-written files start from.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/skeleton_build.dart';
import 'package:mcgen/src/emit/feature_search/skeleton_templates.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _model = 'lib/src/domain/model';
const _widget = 'lib/src/presentation/widget';

/// The variables every skeleton template draws on.
Map<String, String> skeletonVars(SrModel m) {
  final s = m.skel;
  final entity = m.entity;
  return {
    'module': m.module,
    'Pascal': m.pascal,
    'camel': m.camel,
    'Entity': entity,
    'entity': camelCase(entity),
    'Dto': '${entity}Dto',
    'ImageDto': s('image_dto'),
    'Id': m.openId,
    'idFile': m.ids.firstWhere((i) => i.name == m.openId).file,
    'title': s('title'),
    'Title': pascalCase(s('title')),
    'image': s('image'),
    'items': m.items,
    'Items': pascalCase(m.items),
    'path': s('path'),
    'prefixParam': s('prefix_param'),
    'pageSize': '${m.pageSize}',
    'Facets': m.name('facets'),
    'Query': m.name('query'),
    'Sort': m.name('sort'),
    'Tile': m.name('tile'),
    'tileArg': m.name('tile_arg'),
    'FacetsView': m.name('facets_view'),
    'Record': s('record'),
    'records': s('records'),
    'fixturePackage': s('fixture_package'),
    'Domain': s('domain'),
    'fixtureSets': s('fixture_sets'),
    'fixtureSet': s('fixture_set'),
    'lookup': m.tests['lookup.${m.openCalls}'] ?? '${camelCase(entity)}Named',
    'open': m.openCalls,
    'Repository': m.repository,
    'Flow': m.flow,
    'Navigator': m.navigator,
    'MockNavigator': 'Mock${m.navigator}',
    'moduleDir': m.spec.moduleDir,
    'exampleQuery': s('example_query'),
    'exampleTitle': s('example_title'),
    'L10n': m.l10nClass,
    'tag': m.tag('flow_scope'),
    'entityFile': m.file('entity'),
    'facetsFile': m.file('facets'),
    'tileFile': m.file('tile'),
    'emptyFile': m.file('empty_message'),
    'facetsViewFile': m.file('facets_view'),
    'dtoFile': '${snakeCase(entity)}_dto.dart',
    'mapperFile': '${snakeCase(entity)}_mapper.dart',
    'envFile': '${m.module}_env.dart',
  };
}

void emitSkeleton(EmitContext ctx, SrModel m) {
  final v = skeletonVars(m);
  final sorts = m.sorts;
  String t(String raw, [Map<String, String> extra = const {}]) =>
      tpl(raw, {...v, ...extra});
  void lib(
    String path,
    List<String> imports,
    String body, {
    List<String> parts = const [],
    String? name,
  }) => ctx.library(
    DartLibrary(
      path,
      imports: imports,
      parts: parts,
      decls: [RawDecl(Code(body), name: name)],
    ),
    owned: true,
  );

  lib(
    'lib/src/domain/api/${m.module}_api.dart',
    [
      m.uri('domain/model/${v['dtoFile']}'),
      'package:dio/dio.dart',
      'package:injectable/injectable.dart',
      'package:mc_api_client/mc_api_client.dart',
      'package:retrofit/retrofit.dart',
    ],
    t(skelApi),
    parts: ['${m.module}_api.g.dart'],
    name: '${m.pascal}Api',
  );
  lib(
    '$_model/${v['dtoFile']}',
    ['package:freezed_annotation/freezed_annotation.dart'],
    t(skelDto),
    parts: [
      '${snakeCase(m.entity)}_dto.freezed.dart',
      '${snakeCase(m.entity)}_dto.g.dart',
    ],
    name: v['Dto'],
  );
  lib(
    '$_model/${m.file('entity')}',
    [
      m.uri('domain/model/${v['idFile']}'),
      'package:freezed_annotation/freezed_annotation.dart',
      'package:mc_media/mc_media.dart',
    ],
    t(skelEntity),
    parts: ['${m.file('entity').replaceFirst('.dart', '')}.freezed.dart'],
    name: m.entity,
  );
  lib(
    '$_model/${v['mapperFile']}',
    [
      m.uri('domain/model/${m.file('entity')}'),
      m.uri('domain/model/${v['dtoFile']}'),
      m.uri('domain/model/${v['idFile']}'),
      'package:mc_api_client/mc_api_client.dart',
      'package:mc_media/mc_media.dart',
      'package:mc_paging/mc_paging.dart',
    ],
    t(skelMapper),
    name: '${v['Dto']}Mapper',
  );
  lib(
    '$_model/${m.file('facets')}',
    const [],
    t(skelFacets, {
      'sortValues': [
        for (final s in sorts) "  ${s.$1}('${s.$2}')",
      ].join(',\n'),
      'defaultSort': sorts.first.$1,
    }),
    name: m.name('sort'),
  );
  lib(
    'lib/src/domain/repository/${m.module}_repository.dart',
    [
      m.uri('domain/api/${m.module}_api.dart'),
      m.uri('domain/model/${m.file('entity')}'),
      m.uri('domain/model/${m.file('facets')}'),
      m.uri('domain/model/${v['mapperFile']}'),
      'package:injectable/injectable.dart',
      'package:mc_api_client/mc_api_client.dart',
      'package:mc_api_errors/mc_api_errors.dart',
      'package:mc_paging/mc_paging.dart',
      'package:mc_prelude/mc_prelude.dart',
    ],
    t(skelRepository),
    name: m.repository,
  );
  lib(
    '$_widget/${m.file('tile')}',
    [
      m.uri('domain/model/${m.file('entity')}'),
      m.uri('presentation/bloc/${m.module}_bloc.dart'),
      'package:flutter/material.dart',
      'package:flutter_bloc/flutter_bloc.dart',
      'package:mc_ds_media/mc_ds_media.dart',
      'package:mc_media/mc_media.dart',
    ],
    t(skelTile),
    name: m.name('tile'),
  );
  lib(
    '$_widget/${m.file('facets_view')}',
    [
      m.uri('domain/model/${m.file('facets')}'),
      m.uri('l10n/${m.module}_l10n.dart'),
      m.uri('presentation/bloc/${m.module}_bloc.dart'),
      'package:flutter/material.dart',
      'package:flutter_bloc/flutter_bloc.dart',
      'package:mc_ds_inputs/mc_ds_inputs.dart',
      'package:mc_ds_layout/mc_ds_layout.dart',
    ],
    t(skelFacetsView, {
      'sortLabels': [
        for (final s in sorts)
          '      ${m.name('sort')}.${s.$1} => l10n.${m.key('Sort${pascalCase(s.$1)}')},',
      ].join('\n'),
      'defaultSort': sorts.first.$1,
    }),
    name: m.name('facets_view'),
  );
  lib(
    '$_widget/${m.file('empty_message')}',
    [m.uri('l10n/${m.module}_l10n.dart')],
    t(skelEmpty),
    name: 'emptySearchMessage',
  );
  ctx.library(skelEnv(m, v), owned: true);
  ctx.library(skelFlowScopeTest(m, v), owned: true);
  ctx.library(skelContractTest(m, v), owned: true);
  emitSkeletonBuild(ctx, m, v);
}
