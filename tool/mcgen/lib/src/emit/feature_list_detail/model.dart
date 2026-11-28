// The list-detail (LD) archetype's model (plan 01 section 3.3, P2-04): a
// paged grid of one entity, an in-flow preview of the tapped item with
// actions that leave the feature, and preview sections that each list items
// related to it. ADR-0017 records the shape.
//
// The core spec carries what every archetype shares (entities, endpoints,
// navigator, l10n strings, BDD). `options` carries the LD-specific wiring,
// validated here: which entity the list pages, which endpoint feeds it, the
// list's filters, the preview's actions and sections, the mappers, and the
// test environment's names. Every name the templates derive (classes, keys,
// strings) follows from the module name and these nouns, so a spec states
// each fact once.

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/core/spec/types.dart';
import 'package:yaml/yaml.dart';

/// Thrown by [LdModel.parse] for options it cannot read; lint reports them.
class LdError implements Exception {
  LdError(this.node, this.path, this.message);

  final YamlNode? node;
  final String path;
  final String message;
}

/// An id extension type (`extension type const CharacterId(int value) {}`).
class LdId {
  const LdId(this.name, this.type, this.doc);

  final String name;
  final String type;
  final String? doc;

  String get file => '${snakeCase(name)}.dart';
}

/// A list filter: a flow argument that narrows the list's query
/// (`initialTeamId` -> flow state `teamId` -> query `team`).
class LdFilter {
  const LdFilter({
    required this.name,
    required this.type,
    required this.query,
    required this.arg,
    this.doc,
    this.argDoc,
    this.queryDoc,
  });

  /// The flow state's and the query object's field (`teamId`).
  final String name;
  final TypeExpr type;

  /// The endpoint's query parameter it fills (`team`).
  final String query;

  /// The flow's constructor argument (`initialTeamId`).
  final String arg;
  final String? doc;
  final String? argDoc;
  final String? queryDoc;
}

/// A preview action: a button whose event leaves the feature through a
/// navigator method, with the previewed item's id.
class LdAction {
  const LdAction(this.event, this.calls, this.doc);

  final String event;
  final String calls;
  final String? doc;

  /// The l10n key suffix (`PreviewSeeFullProfile`).
  String get stringKey => 'Preview${pascalCase(event)}';
}

/// A preview section: items related to the previewed one, from their own
/// endpoint, each leaving the feature through a navigator method.
class LdSection {
  const LdSection({
    required this.name,
    required this.words,
    required this.item,
    required this.items,
    required this.entity,
    required this.endpoint,
    required this.by,
    required this.limit,
    required this.title,
    required this.image,
    required this.imageVariant,
    required this.calls,
    required this.strings,
    required this.key,
  });

  /// The widget's class name (`RelatedComics`).
  final String name;

  /// How prose names the section (`related comics`).
  final String words;
  final String item;
  final String items;
  final String entity;
  final String endpoint;

  /// The endpoint's query parameter that takes the previewed item's id.
  final String by;
  final int limit;
  final String title;
  final String image;
  final String imageVariant;
  final String calls;

  /// The l10n key infix (`Comics` -> `charactersListPreviewComics...`).
  final String strings;

  /// The widget key's last segment (`characters_list.preview.comics`).
  final String key;

  String get camel => camelCase(name);
  String get snake => snakeCase(name);
  String get bloc => '${name}Bloc';
  String get event => '${name}Event';
  String get state => '${name}State';
}

/// A DTO -> domain mapper. [fields] renames (domain field -> DTO field);
/// [via] converts a DTO field with a callable (`ImageVariant.fromWire`).
class LdMapper {
  const LdMapper(this.dto, this.to, this.fields, this.via);

  final String dto;
  final String to;
  final Map<String, String> fields;
  final Map<String, String> via;
}

/// The fixture records the test environment looks items up in.
class LdRecord {
  const LdRecord({required this.id, required this.title, required this.image});

  final String id;
  final String title;
  final String image;
}

class LdTests {
  const LdTests({
    required this.fixtureSets,
    required this.records,
    required this.record,
    required this.sectionRecords,
    required this.tags,
    required this.legacyGoldens,
    required this.env,
  });

  /// Fixture sets every flow test serves first (`characters.default`).
  final List<String> fixtureSets;

  /// The env's list of the default set's records, in list order.
  final String records;
  final LdRecord record;

  /// Section name -> its records' fields.
  final Map<String, LdRecord> sectionRecords;

  /// Test slot -> the AC id its name starts with.
  final Map<String, String> tags;

  /// The exemplar's goldens predate ADR-0015: BUILD keeps their target.
  final bool legacyGoldens;

  /// What the env's first write needs (owned afterwards).
  final Map<String, String> env;
}

class LdModel {
  LdModel._(this.spec);

  final ModuleSpec spec;

  late final String item;
  late final String items;
  late final String listNoun;
  late final List<LdId> ids;
  late final String listEntity;
  late final String listEndpoint;
  late final int pageSize;
  late final String titleField;
  late final String imageField;
  late final List<LdFilter> filters;
  late final List<LdMapper> mappers;
  late final String artVariant;
  late final List<LdAction> actions;
  late final List<LdSection> sections;
  late final LdTests tests;
  late final Map<String, String> prose;
  late final Map<String, List<String>> imports;

  // --- names ------------------------------------------------------------------
  String get module => spec.module;
  String get pascal => pascalCase(module);
  String get camel => camelCase(module);
  String get itemPascal => pascalCase(item.replaceAll(' ', '_'));
  String get itemCamel => camelCase(item.replaceAll(' ', '_'));
  String get itemsCamel => camelCase(items.replaceAll(' ', '_'));
  String get itemsPascal => pascalCase(items.replaceAll(' ', '_'));
  String get listEntityId => idOf(listEntity)!;

  String get navigator => spec.navigator!.name;
  String get flow => '${pascal}Flow';
  String get flowState => '${pascal}FlowState';
  String get api => '${pascal}Api';
  String get repository => '${pascal}Repository';
  String get listBloc => '${pascal}Bloc';
  String get listEvent => '${pascal}Event';
  String get listState => '${pascal}State';
  String get listPage => '${pascal}Page';
  String get previewPage => '${itemPascal}PreviewPage';
  String get previewBloc => '${itemPascal}PreviewBloc';
  String get previewEvent => '${itemPascal}PreviewEvent';
  String get tile => '${itemPascal}Tile';
  String get query => '${itemsPascal}Query';
  String get diInitializer => '${pascal}DIInitializer';
  String get rootImports => '${camel}RootImports';
  String get l10nClass => '${pascal}L10n';
  String get pageSizeConst => '${itemsCamel}PageSize';
  String get gridKey => '${itemsCamel}GridKey';
  String get previewTitleKey => '${itemCamel}PreviewTitleKey';
  String get previewArtKey => '${itemCamel}PreviewArtKey';
  String get dtoFile => '${snakeCase(listEntity)}_dto.dart';
  String get mapperFile => '${snakeCase(listEntity)}_mapper.dart';
  String get queryFile => '${snakeCase(query)}.dart';

  /// The l10n key of [suffix] (`Title` -> `charactersListTitle`).
  String key(String suffix) => '$camel$suffix';

  EntitySpec entity(String name) =>
      spec.entities.firstWhere((e) => e.name == name);

  EndpointSpec endpoint(String id) =>
      spec.endpoints.firstWhere((e) => e.id == id);

  List<EntitySpec> get domainEntities => [
    for (final e in spec.entities)
      if (e.json != true) e,
  ];

  List<EntitySpec> get dtos => [
    for (final e in spec.entities)
      if (e.json == true) e,
  ];

  /// The id type of [entity]: the type of its `id` field, when an id.
  String? idOf(String entity) {
    for (final e in spec.entities) {
      if (e.name != entity) continue;
      for (final f in e.fields) {
        if (f.name == 'id' && ids.any((i) => i.name == f.type.name)) {
          return f.type.name;
        }
      }
    }
    return null;
  }

  /// The navigator method [name]'s argument type.
  String navigatorArg(String name) =>
      spec.navigator!.outbound.firstWhere((o) => o.name == name).args.single;

  /// The entity whose id the navigator method [name] takes.
  String entityOpenedBy(String name) {
    final id = navigatorArg(name);
    return spec.entities.firstWhere((e) => idOf(e.name) == id).name;
  }

  /// The prose of [slot]: the spec's `options.prose`, else [fallback].
  String text(String slot, String fallback) => prose[slot] ?? fallback;

  /// The prose of [slot], or null when the spec gives none and there is no
  /// default.
  String? textOr(String slot, String? fallback) => prose[slot] ?? fallback;

  /// The AC tag a test name starts with, plus a space; empty when untagged.
  String tag(String slot) {
    final t = tests.tags[slot];
    return t == null ? '' : '$t ';
  }

  // --- parsing ------------------------------------------------------------------

  /// Reads `spec.options`. Throws [LdError] on the first problem.
  static LdModel parse(ModuleSpec spec) {
    final m = LdModel._(spec);
    final r = _Reader(spec.optionsNode, 'options');
    m.item = r.str('item');
    m.items = r.str('items');
    m.listNoun = r.str('list_noun', '${m.items} list');
    m.ids = [
      for (final (i, n) in r.list('ids').indexed)
        () {
          final x = _Reader(n, 'options.ids[$i]');
          return LdId(x.str('name'), x.str('type'), x.optStr('doc'));
        }(),
    ];
    final list = r.child('list');
    m.listEntity = list.str('entity');
    m.listEndpoint = list.str('endpoint');
    m.pageSize = list.integer('page_size');
    m.titleField = list.str('title');
    m.imageField = list.str('image');
    m.filters = [
      for (final (i, n) in list.list('filters').indexed)
        () {
          final x = _Reader(n, 'options.list.filters[$i]');
          final name = x.str('name');
          return LdFilter(
            name: name,
            type: TypeExpr.parse(x.str('type')),
            query: x.str('query'),
            arg: x.str('arg', 'initial${pascalCase(name)}'),
            doc: x.optStr('doc'),
            argDoc: x.optStr('arg_doc'),
            queryDoc: x.optStr('query_doc'),
          );
        }(),
    ];
    m.mappers = [
      for (final (i, n) in r.list('mappers').indexed)
        () {
          final x = _Reader(n, 'options.mappers[$i]');
          return LdMapper(
            x.str('dto'),
            x.str('to'),
            x.strMap('fields'),
            x.strMap('via'),
          );
        }(),
    ];
    final preview = r.child('preview');
    m.artVariant = preview.str('art_variant', 'portraitLarge');
    m.actions = [
      for (final (i, n) in preview.list('actions').indexed)
        () {
          final x = _Reader(n, 'options.preview.actions[$i]');
          return LdAction(x.str('event'), x.str('calls'), x.optStr('doc'));
        }(),
    ];
    m.sections = [
      for (final (i, n) in preview.list('sections').indexed)
        () {
          final x = _Reader(n, 'options.preview.sections[$i]');
          final name = x.str('name');
          final items = x.str('items');
          return LdSection(
            name: name,
            words: x.str('words', snakeCase(name).replaceAll('_', ' ')),
            item: x.str('item'),
            items: items,
            entity: x.str('entity'),
            endpoint: x.str('endpoint'),
            by: x.str('by'),
            limit: x.integer('limit'),
            title: x.str('title'),
            image: x.str('image'),
            imageVariant: x.str('image_variant', 'portraitSmall'),
            calls: x.str('calls'),
            strings: x.str('strings', pascalCase(items)),
            key: x.str('key', items),
          );
        }(),
    ];
    final t = r.child('tests');
    LdRecord record(_Reader x) => LdRecord(
      id: x.str('id', 'id'),
      title: x.str('title'),
      image: x.str('image'),
    );
    m.tests = LdTests(
      fixtureSets: t.strList('fixture_sets'),
      records: t.str('records', 'default${m.itemsPascal}'),
      record: record(t.child('record')),
      sectionRecords: {
        for (final s in m.sections)
          s.name: record(t.child('section_records').child(s.name)),
      },
      tags: t.strMap('tags'),
      legacyGoldens: t.boolean('legacy_goldens'),
      env: t.strMap('env'),
    );
    m.prose = r.strMap('prose');
    m.imports = {
      for (final e in r.child('imports').entries)
        e.key: [for (final u in (e.value as YamlList).nodes) '${u.value}'],
    };
    return m;
  }

  /// Archetype lint: the options parse, and the names they use exist.
  static List<Diagnostic> lint(ModuleSpec spec) {
    final out = <Diagnostic>[];
    void err(YamlNode? node, String path, String message) => out.add(
      Diagnostic.at(
        node ?? spec.node,
        code: 'list_detail',
        message: message,
        file: spec.file,
        yamlPath: path,
      ),
    );
    if (spec.navigator == null) {
      err(spec.node, 'navigator', 'list_detail needs a navigator');
    }
    if (spec.l10n == null) {
      err(spec.node, 'l10n', 'list_detail needs l10n strings');
    }
    if (spec.bdd.isEmpty) {
      err(spec.node, 'bdd', 'list_detail needs at least one BDD feature');
    }
    final LdModel m;
    try {
      m = parse(spec);
    } on LdError catch (e) {
      err(e.node, e.path, e.message);
      return out;
    } on FormatException catch (e) {
      err(spec.optionsNode, 'options', e.message);
      return out;
    }
    if (out.isNotEmpty) return out;
    final entities = {for (final e in spec.entities) e.name: e};
    final endpoints = {for (final e in spec.endpoints) e.id: e};
    final methods = {for (final o in spec.navigator!.outbound) o.name: o};
    void entity(String name, String path) {
      if (!entities.containsKey(name)) {
        err(spec.optionsNode, path, 'no entity "$name" in entities');
      }
    }

    void endpointOf(String id, String path) {
      if (!endpoints.containsKey(id)) {
        err(spec.optionsNode, path, 'no endpoint "$id" in endpoints');
      }
    }

    void method(String name, String path) {
      final o = methods[name];
      if (o == null) {
        err(spec.optionsNode, path, 'the navigator has no method "$name"');
      } else if (o.args.length != 1 || !m.ids.any((i) => i.name == o.args[0])) {
        err(
          spec.optionsNode,
          path,
          'navigator method "$name" must take one id type of options.ids',
        );
      }
    }

    entity(m.listEntity, 'options.list.entity');
    endpointOf(m.listEndpoint, 'options.list.endpoint');
    if (m.idOf(m.listEntity) == null && entities.containsKey(m.listEntity)) {
      err(
        spec.optionsNode,
        'options.list.entity',
        '"${m.listEntity}" needs an id field typed with one of options.ids',
      );
    }
    for (final (i, a) in m.actions.indexed) {
      method(a.calls, 'options.preview.actions[$i].calls');
    }
    for (final (i, s) in m.sections.indexed) {
      entity(s.entity, 'options.preview.sections[$i].entity');
      endpointOf(s.endpoint, 'options.preview.sections[$i].endpoint');
      method(s.calls, 'options.preview.sections[$i].calls');
    }
    for (final (i, x) in m.mappers.indexed) {
      entity(x.dto, 'options.mappers[$i].dto');
    }
    final strings = {
      for (final s in spec.l10n?.strings ?? const <L10nStringSpec>[]) s.key: s,
    };
    final locales = spec.l10n?.locales ?? const [];
    for (final k in m.requiredStrings) {
      final s = strings[k];
      if (s == null) {
        err(spec.node, 'l10n.strings', 'list_detail needs the string "$k"');
        continue;
      }
      for (final l in locales) {
        if (l != 'en_XA' && !s.text.containsKey(l)) {
          err(s.node, '${s.path}.text', '"$k" has no "$l" text');
        }
      }
    }
    return out;
  }

  /// Every l10n key the templates use.
  List<String> get requiredStrings => [
    for (final s in [
      'Title',
      'Loading',
      'EmptyTitle',
      'EmptyMessage',
      'ErrorTitle',
      'LoadMoreFailed',
    ])
      key(s),
    for (final a in actions) key(a.stringKey),
    for (final s in sections)
      for (final suffix in ['', 'Loading', 'Empty', 'Failed'])
        key('Preview${s.strings}$suffix'),
  ];
}

/// Reads one options map, naming the YAML path in errors.
class _Reader {
  _Reader(this.node, this.path);

  final YamlNode? node;
  final String path;

  YamlMap? get _map => node is YamlMap ? node! as YamlMap : null;

  Never fail(String key, String message) =>
      throw LdError(_map?.nodes[key] ?? node, '$path.$key', message);

  Object? _value(String key) => _map?[key];

  String str(String key, [String? fallback]) {
    final v = _value(key);
    if (v == null && fallback != null) return fallback;
    if (v is! String || v.isEmpty) fail(key, '"$key" must be a string');
    return v;
  }

  String? optStr(String key) {
    final v = _value(key);
    if (v == null) return null;
    if (v is! String) fail(key, '"$key" must be a string');
    return v;
  }

  int integer(String key) {
    final v = _value(key);
    if (v is! int) fail(key, '"$key" must be an integer');
    return v;
  }

  bool boolean(String key) {
    final v = _value(key);
    if (v == null) return false;
    if (v is! bool) fail(key, '"$key" must be true or false');
    return v;
  }

  List<YamlNode> list(String key) {
    final n = _map?.nodes[key];
    if (n == null) return const [];
    if (n is! YamlList) fail(key, '"$key" must be a list');
    return n.nodes;
  }

  List<String> strList(String key) => [
    for (final n in list(key)) '${n.value}',
  ];

  _Reader child(String key) {
    final n = _map?.nodes[key];
    if (n != null && n is! YamlMap) fail(key, '"$key" must be a map');
    return _Reader(n, '$path.$key');
  }

  Iterable<MapEntry<String, YamlNode>> get entries => [
    for (final e in _map?.nodes.entries ?? const <MapEntry<Object?, YamlNode>>[])
      MapEntry('${(e.key as YamlNode).value}', e.value),
  ];

  Map<String, String> strMap(String key) {
    final c = child(key);
    return {for (final e in c.entries) e.key: '${e.value.value}'};
  }
}
