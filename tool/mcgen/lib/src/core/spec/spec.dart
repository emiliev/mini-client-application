// The typed `mcgen/1` spec model (plan 02 section 2.2, ADR-0016) and its
// loader. Schema validation runs first; the loader then builds typed objects
// that keep their YAML node, so later checks can still point at a line.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/spec/schema_validator.dart';
import 'package:mcgen/src/core/spec/types.dart';
import 'package:yaml/yaml.dart';

enum Tier { app, feature, utility }

enum Ownership { managed, mixed, ejected }

/// Something loaded from the spec, with its location.
abstract class SpecPart {
  SpecPart(this.node, this.path);

  final YamlNode node;

  /// The YAML path, e.g. `entities[0].fields[1]`.
  final String path;

  /// The node of [key] inside this part (or this part's node).
  YamlNode nodeOf(String key) {
    final n = node;
    if (n is YamlMap) return n.nodes[key] ?? n;
    return n;
  }
}

class FieldSpec extends SpecPart {
  FieldSpec(
    super.node,
    super.path, {
    required this.name,
    required this.type,
    this.defaultValue,
    this.hasDefault = false,
    this.unknown,
    this.jsonKey,
    this.doc,
  });

  final String name;
  final TypeExpr type;
  final Object? defaultValue;
  final bool hasDefault;
  final String? unknown;
  final String? jsonKey;
  final String? doc;
}

enum EntityKind { model, enumeration, union }

class EntitySpec extends SpecPart {
  EntitySpec(
    super.node,
    super.path, {
    required this.name,
    required this.kind,
    this.fields = const [],
    this.values = const [],
    this.variants = const [],
    this.unionKey,
    this.json,
    this.doc,
  });

  final String name;
  final EntityKind kind;
  final List<FieldSpec> fields;

  /// Enum values.
  final List<String> values;

  /// Union variants, e.g. `team(TeamRef)`.
  final List<Signature> variants;
  final String? unionKey;
  final bool? json;
  final String? doc;
}

/// A query parameter (ADR-0017): a bare name, or a typed one.
class QueryParamSpec extends SpecPart {
  QueryParamSpec(
    super.node,
    super.path, {
    required this.name,
    this.type,
    this.defaultValue,
    this.hasDefault = false,
    this.required = false,
    this.doc,
  });

  final String name;

  /// Null for a bare name: the archetype picks the type.
  final TypeExpr? type;
  final Object? defaultValue;
  final bool hasDefault;
  final bool required;
  final String? doc;
}

class EndpointSpec extends SpecPart {
  EndpointSpec(
    super.node,
    super.path, {
    required this.id,
    required this.method,
    required this.urlPath,
    this.params = const [],
    this.body,
    this.returns,
    this.auth = false,
    this.doc,
  });

  final String id;
  final String method;
  final String urlPath;

  /// The query parameters, in order.
  final List<QueryParamSpec> params;

  /// Their names.
  List<String> get query => [for (final q in params) q.name];
  final TypeExpr? body;
  final TypeExpr? returns;
  final bool auth;
  final String? doc;
}

class RuleCase {
  const RuleCase(this.when, this.then);

  final String when;
  final Object? then;
}

class RuleSpec extends SpecPart {
  RuleSpec(
    super.node,
    super.path, {
    required this.id,
    required this.kind,
    this.input,
    this.cases = const [],
    this.defaultValue,
    this.examples = const [],
    this.doc,
  });

  final String id;
  final String kind;
  final TypeExpr? input;
  final List<RuleCase> cases;
  final Object? defaultValue;

  /// Each example is the input values plus `expect` (C8: tests come only
  /// from these).
  final List<Map<String, Object?>> examples;
  final String? doc;
}

class BlocSpec extends SpecPart {
  BlocSpec(
    super.node,
    super.path, {
    required this.name,
    required this.states,
    required this.events,
    this.transformers = const {},
    this.doc,
  });

  final String name;
  final List<Signature> states;
  final List<Signature> events;
  final Map<String, String> transformers;
  final String? doc;
}

class FlowSpec extends SpecPart {
  FlowSpec(
    super.node,
    super.path, {
    required this.pages,
    this.name,
    this.state = const [],
    this.args = const [],
    this.result,
    this.doc,
  });

  final String? name;
  final List<FieldSpec> state;
  final List<String> pages;
  final List<FieldSpec> args;
  final TypeExpr? result;
  final String? doc;
}

class ScreenSpec extends SpecPart {
  ScreenSpec(
    super.node,
    super.path, {
    required this.name,
    this.layout,
    this.depth,
    this.widgets,
    this.doc,
  });

  final String name;
  final String? layout;
  final int? depth;
  final int? widgets;
  final String? doc;
}

class NavigatorSpec extends SpecPart {
  NavigatorSpec(
    super.node,
    super.path, {
    required this.name,
    required this.outbound,
    this.doc,
  });

  final String name;
  final List<Signature> outbound;
  final String? doc;
}

/// One string of the module's ARBs (ADR-0017).
class L10nStringSpec extends SpecPart {
  L10nStringSpec(
    super.node,
    super.path, {
    required this.key,
    required this.text,
    this.description,
    this.placeholders = const {},
  });

  final String key;

  /// gen-l10n's `placeholders` metadata, as given (`{count: {type: int}}`).
  final Map<String, Object?> placeholders;

  /// Locale -> text, in the spec's order.
  final Map<String, String> text;
  final String? description;
}

class L10nSpec extends SpecPart {
  L10nSpec(
    super.node,
    super.path, {
    required this.locales,
    this.keys = 0,
    this.placeholders = 0,
    this.plurals = 0,
    this.selects = 0,
    this.strings = const [],
  });

  final List<String> locales;
  final int keys;
  final int placeholders;
  final int plurals;
  final int selects;
  final List<L10nStringSpec> strings;
}

class MixinSpec extends SpecPart {
  MixinSpec(super.node, super.path, {required this.name, this.on});

  final String name;
  final String? on;
}

class ScenarioSpec extends SpecPart {
  ScenarioSpec(
    super.node,
    super.path, {
    required this.title,
    required this.steps,
    this.id,
    this.tags = const [],
    this.examples = const [],
  });

  /// `MC-<module>-NN`; null only in an exemplar (ADR-0017).
  final String? id;
  final String title;
  final List<String> steps;
  final List<String> tags;

  /// A Scenario Outline's Examples table, header row first; empty for a
  /// plain scenario.
  final List<List<String>> examples;
}

class OutlineSpec extends SpecPart {
  OutlineSpec(
    super.node,
    super.path, {
    required this.id,
    required this.rule,
    required this.title,
    this.steps = const [],
    this.tags = const [],
  });

  final String id;
  final String rule;
  final String title;

  /// The Scenario Outline's steps; its Examples are the rule's examples.
  final List<String> steps;
  final List<String> tags;
}

class BddFeatureSpec extends SpecPart {
  BddFeatureSpec(
    super.node,
    super.path, {
    required this.feature,
    this.title,
    this.description,
    this.backgroundSteps = const [],
    this.scenarios = const [],
    this.outlines = const [],
  });

  final String feature;

  /// The `Feature:` line; null: the feature name in words.
  final String? title;

  /// The lines under the `Feature:` line.
  final String? description;

  /// The Background's steps (one or several).
  final List<String> backgroundSteps;

  /// The first background step (the `background: <step>` form).
  String? get background => backgroundSteps.firstOrNull;
  final List<ScenarioSpec> scenarios;
  final List<OutlineSpec> outlines;
}

/// One module's spec.
class ModuleSpec extends SpecPart {
  ModuleSpec(
    super.node,
    super.path, {
    required this.file,
    required this.moduleDir,
    required this.module,
    required this.tier,
    required this.archetype,
    required this.ownership,
    required this.specHash,
    this.exemplar = false,
    this.description,
    this.sizeClass,
    this.seedSalt = 0,
    this.deps = const [],
    this.devDeps = const [],
    this.owned = const [],
    this.keep = const [],
    this.entities = const [],
    this.endpoints = const [],
    this.rules = const [],
    this.blocs = const [],
    this.flow,
    this.screens = const [],
    this.navigator,
    this.l10n,
    this.mixins = const [],
    this.bdd = const [],
    this.options = const {},
    this.optionsNode,
  });

  /// The spec file, relative to the root (`utility/mc_hello/mcgen.yaml`).
  final String file;

  /// The module directory, relative to the root (`utility/mc_hello`).
  final String moduleDir;

  final String module;
  final Tier tier;
  final String archetype;
  final Ownership ownership;

  /// The archetype's hand-built exemplar (ejected; ADR-0017): gen writes
  /// only its manifest and `--check` is the round-trip golden.
  final bool exemplar;

  /// sha256 of the canonical JSON of the document: comments and key order in
  /// the YAML do not change it.
  final String specHash;

  final String? description;
  final String? sizeClass;
  final int seedSalt;
  final List<String> deps;
  final List<String> devDeps;
  final List<String> owned;
  final List<String> keep;
  final List<EntitySpec> entities;
  final List<EndpointSpec> endpoints;
  final List<RuleSpec> rules;
  final List<BlocSpec> blocs;
  final FlowSpec? flow;
  final List<ScreenSpec> screens;
  final NavigatorSpec? navigator;
  final L10nSpec? l10n;
  final List<MixinSpec> mixins;
  final List<BddFeatureSpec> bdd;

  /// Archetype-specific settings, as plain values. The archetype validates
  /// them ([optionsNode] has the spans).
  final Map<String, Object?> options;
  final YamlMap? optionsNode;
}

/// Canonical JSON: object keys sorted by code unit, no whitespace.
String canonicalJson(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalJson(v[k])}').join(',')}}';
  }
  if (v is List) return '[${v.map(canonicalJson).join(',')}]';
  return jsonEncode(v);
}

/// Parses YAML text, reporting a syntax error with its location.
YamlNode parseYamlDocument(String text, String file) {
  try {
    return loadYamlNode(text, sourceUrl: Uri.file(file));
  } on YamlException catch (e) {
    final start = e.span?.start;
    throw McgenException.single(
      Diagnostic(
        code: 'yaml',
        message: e.message,
        file: file,
        line: start == null ? 0 : start.line + 1,
        column: start == null ? 0 : start.column + 1,
      ),
    );
  }
}

/// Loads a spec: YAML, then the schema, then the typed model. Throws
/// [McgenException] with every diagnostic found.
ModuleSpec loadSpec({
  required String text,
  required String file,
  required SpecSchema schema,
}) {
  final doc = parseYamlDocument(text, file);
  final schemaErrors = schema.validate(doc, file);
  if (schemaErrors.isNotEmpty) throw McgenException(schemaErrors);
  return _Loader(file).module(doc as YamlMap);
}

class _Loader {
  _Loader(this.file);

  final String file;
  final errors = <Diagnostic>[];

  void err(YamlNode n, String path, String code, String message) => errors.add(
    Diagnostic.at(n, code: code, message: message, file: file, yamlPath: path),
  );

  T? opt<T>(YamlMap m, String key) {
    final v = m[key];
    return v is T ? v : null;
  }

  List<YamlNode> list(YamlMap m, String key) {
    final n = m.nodes[key];
    return n is YamlList ? n.nodes : const [];
  }

  List<String> strings(YamlMap m, String key) => [
    for (final n in list(m, key)) '${n.value}',
  ];

  TypeExpr? type(YamlMap m, String key, String path) {
    final n = m.nodes[key];
    if (n == null) return null;
    try {
      return TypeExpr.parse('${n.value}');
    } on FormatException catch (e) {
      err(n, '$path.$key', 'type-syntax', e.message);
      return const TypeExpr('Object');
    }
  }

  Signature sig(YamlNode n, String path) {
    try {
      return Signature.parse('${n.value}');
    } on FormatException catch (e) {
      err(n, path, 'signature-syntax', e.message);
      return const Signature('invalid');
    }
  }

  FieldSpec field(YamlMap m, String path) => FieldSpec(
    m,
    path,
    name: m['name'] as String,
    type: type(m, 'type', path)!,
    defaultValue: m.nodes['default'] == null
        ? null
        : yamlToPlain(m.nodes['default']!),
    hasDefault: m.containsKey('default'),
    unknown: opt<String>(m, 'unknown'),
    jsonKey: opt<String>(m, 'json_key'),
    doc: opt<String>(m, 'doc'),
  );

  List<FieldSpec> fields(YamlMap m, String key, String path) => [
    for (final (i, n) in list(m, key).indexed)
      field(n as YamlMap, '$path.$key[$i]'),
  ];

  EntitySpec entity(YamlMap m, String path) {
    final present = [
      for (final k in ['fields', 'enum', 'union'])
        if (m.containsKey(k)) k,
    ];
    if (present.length != 1) {
      err(
        m,
        path,
        'entity-kind',
        present.isEmpty
            ? 'entity "${m['name']}" needs one of fields, enum or union'
            : 'entity "${m['name']}" has ${present.join(' and ')}; use exactly one',
      );
    }
    if (m.containsKey('union_key') && !m.containsKey('union')) {
      err(
        m.nodes['union_key']!,
        '$path.union_key',
        'entity-kind',
        'union_key without union',
      );
    }
    final kind = switch (present.firstOrNull) {
      'enum' => EntityKind.enumeration,
      'union' => EntityKind.union,
      _ => EntityKind.model,
    };
    return EntitySpec(
      m,
      path,
      name: m['name'] as String,
      kind: kind,
      fields: fields(m, 'fields', path),
      values: strings(m, 'enum'),
      variants: [
        for (final (i, n) in list(m, 'union').indexed)
          sig(n, '$path.union[$i]'),
      ],
      unionKey: opt<String>(m, 'union_key'),
      json: opt<bool>(m, 'json'),
      doc: opt<String>(m, 'doc'),
    );
  }

  ModuleSpec module(YamlMap m) {
    final tier = Tier.values.byName(m['tier'] as String);
    final ownership = Ownership.values.byName(m['ownership'] as String);
    final moduleDir = file.contains('/')
        ? file.substring(0, file.lastIndexOf('/'))
        : '.';
    final optionsNode = m.nodes['options'];
    final flowNode = m.nodes['flow'];
    final navNode = m.nodes['navigator'];
    final l10nNode = m.nodes['l10n'];
    final spec = ModuleSpec(
      m,
      '',
      file: file,
      moduleDir: moduleDir,
      module: m['module'] as String,
      tier: tier,
      archetype: m['archetype'] as String,
      ownership: ownership,
      exemplar: opt<bool>(m, 'exemplar') ?? false,
      specHash: sha256
          .convert(utf8.encode(canonicalJson(yamlToPlain(m))))
          .toString(),
      description: opt<String>(m, 'description'),
      sizeClass: opt<String>(m, 'size_class'),
      seedSalt: opt<int>(m, 'seed_salt') ?? 0,
      deps: strings(m, 'deps'),
      devDeps: strings(m, 'dev_deps'),
      owned: strings(m, 'owned'),
      keep: strings(m, 'keep'),
      entities: [
        for (final (i, n) in list(m, 'entities').indexed)
          entity(n as YamlMap, 'entities[$i]'),
      ],
      endpoints: [
        for (final (i, n) in list(m, 'endpoints').indexed)
          _endpoint(n as YamlMap, 'endpoints[$i]'),
      ],
      rules: [
        for (final (i, n) in list(m, 'rules').indexed)
          _rule(n as YamlMap, 'rules[$i]'),
      ],
      blocs: [
        for (final (i, n) in list(m, 'blocs').indexed)
          _bloc(n as YamlMap, 'blocs[$i]'),
      ],
      flow: flowNode is YamlMap ? _flow(flowNode) : null,
      screens: [
        for (final (i, n) in list(m, 'screens').indexed)
          ScreenSpec(
            n,
            'screens[$i]',
            name: (n as YamlMap)['name'] as String,
            layout: opt<String>(n, 'layout'),
            depth: opt<int>(n, 'depth'),
            widgets: opt<int>(n, 'widgets'),
            doc: opt<String>(n, 'doc'),
          ),
      ],
      navigator: navNode is YamlMap
          ? NavigatorSpec(
              navNode,
              'navigator',
              name: navNode['name'] as String,
              outbound: [
                for (final (i, n) in list(navNode, 'outbound').indexed)
                  sig(n, 'navigator.outbound[$i]'),
              ],
              doc: opt<String>(navNode, 'doc'),
            )
          : null,
      l10n: l10nNode is YamlMap
          ? L10nSpec(
              l10nNode,
              'l10n',
              locales: strings(l10nNode, 'locales'),
              keys: opt<int>(l10nNode, 'keys') ?? 0,
              placeholders: opt<int>(l10nNode, 'placeholders') ?? 0,
              plurals: opt<int>(l10nNode, 'plurals') ?? 0,
              selects: opt<int>(l10nNode, 'selects') ?? 0,
              strings: [
                for (final (i, n) in list(l10nNode, 'strings').indexed)
                  L10nStringSpec(
                    n,
                    'l10n.strings[$i]',
                    key: (n as YamlMap)['key'] as String,
                    description: opt<String>(n, 'description'),
                    placeholders: n.nodes['placeholders'] is YamlMap
                        ? (yamlToPlain(n.nodes['placeholders']!)!
                              as Map<String, Object?>)
                        : const {},
                    text: {
                      for (final e in (n['text'] as YamlMap).entries)
                        '${e.key}': '${e.value}',
                    },
                  ),
              ],
            )
          : null,
      mixins: [
        for (final (i, n) in list(m, 'mixins').indexed)
          MixinSpec(
            n,
            'mixins[$i]',
            name: (n as YamlMap)['name'] as String,
            on: opt<String>(n, 'on'),
          ),
      ],
      bdd: [
        for (final (i, n) in list(m, 'bdd').indexed)
          _bdd(n as YamlMap, 'bdd[$i]'),
      ],
      options: optionsNode is YamlMap
          ? (yamlToPlain(optionsNode)! as Map<String, Object?>)
          : const {},
      optionsNode: optionsNode is YamlMap ? optionsNode : null,
    );
    if (errors.isNotEmpty) {
      errors.sort();
      throw McgenException(errors);
    }
    return spec;
  }

  QueryParamSpec _query(YamlNode n, String path) {
    if (n is! YamlMap) {
      return QueryParamSpec(n, path, name: '${n.value}');
    }
    return QueryParamSpec(
      n,
      path,
      name: n['name'] as String,
      type: type(n, 'type', path),
      defaultValue: n.nodes['default'] == null
          ? null
          : yamlToPlain(n.nodes['default']!),
      hasDefault: n.containsKey('default'),
      required: opt<bool>(n, 'required') ?? false,
      doc: opt<String>(n, 'doc'),
    );
  }

  EndpointSpec _endpoint(YamlMap m, String path) => EndpointSpec(
    m,
    path,
    id: m['id'] as String,
    method: m['method'] as String,
    urlPath: m['path'] as String,
    params: [
      for (final (i, n) in list(m, 'query').indexed)
        _query(n, '$path.query[$i]'),
    ],
    body: type(m, 'body', path),
    returns: type(m, 'returns', path),
    auth: opt<bool>(m, 'auth') ?? false,
    doc: opt<String>(m, 'doc'),
  );

  RuleSpec _rule(YamlMap m, String path) => RuleSpec(
    m,
    path,
    id: m['id'] as String,
    kind: m['kind'] as String,
    input: type(m, 'input', path),
    cases: [
      for (final n in list(m, 'cases'))
        RuleCase((n as YamlMap)['when'] as String, n['then']),
    ],
    defaultValue: m['default'],
    examples: [
      for (final n in list(m, 'examples'))
        yamlToPlain(n)! as Map<String, Object?>,
    ],
    doc: opt<String>(m, 'doc'),
  );

  BlocSpec _bloc(YamlMap m, String path) {
    final t = m.nodes['transformers'];
    return BlocSpec(
      m,
      path,
      name: m['name'] as String,
      states: [
        for (final (i, n) in list(m, 'states').indexed)
          sig(n, '$path.states[$i]'),
      ],
      events: [
        for (final (i, n) in list(m, 'events').indexed)
          sig(n, '$path.events[$i]'),
      ],
      transformers: t is YamlMap
          ? {for (final e in t.entries) '${e.key}': '${e.value}'}
          : const {},
      doc: opt<String>(m, 'doc'),
    );
  }

  FlowSpec _flow(YamlMap m) => FlowSpec(
    m,
    'flow',
    name: opt<String>(m, 'name'),
    state: fields(m, 'state', 'flow'),
    pages: strings(m, 'pages'),
    args: fields(m, 'args', 'flow'),
    result: type(m, 'result', 'flow'),
    doc: opt<String>(m, 'doc'),
  );

  BddFeatureSpec _bdd(YamlMap m, String path) => BddFeatureSpec(
    m,
    path,
    feature: m['feature'] as String,
    title: opt<String>(m, 'title'),
    description: opt<String>(m, 'description'),
    backgroundSteps: switch (m.nodes['background']) {
      YamlList() => strings(m, 'background'),
      final YamlScalar s => ['${s.value}'],
      _ => const [],
    },
    scenarios: [
      for (final (i, n) in list(m, 'scenarios').indexed)
        ScenarioSpec(
          n,
          '$path.scenarios[$i]',
          id: opt<String>(n as YamlMap, 'id'),
          title: n['title'] as String,
          steps: strings(n, 'steps'),
          tags: strings(n, 'tags'),
          examples: [
            for (final row in list(n, 'examples'))
              [for (final c in (row as YamlList).nodes) '${c.value}'],
          ],
        ),
    ],
    outlines: [
      for (final (i, n) in list(m, 'outlines').indexed)
        OutlineSpec(
          n,
          '$path.outlines[$i]',
          id: (n as YamlMap)['id'] as String,
          rule: n['rule'] as String,
          title: n['title'] as String,
          steps: strings(n, 'steps'),
          tags: strings(n, 'tags'),
        ),
    ],
  );
}
