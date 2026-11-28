// The search (SR) archetype's model (plan 01 section 3.3, P2-05; ADR-0017).
//
// One search page: a field whose edits are debounced into one request per
// pause, recent searches kept on `mc_storage`, a generation guard so only
// the latest query's answer shows, and the results in one of two shapes:
//
//  - `paged`: one domain, one `PagingController` per search, facets (sort
//    and filter chips) that the backend applies; a facet change searches
//    again from the first page (`characters_search`).
//  - `grouped`: one request answers every group, a client-side filter picks
//    the groups that show, no paging (`discovery_search`).
//
// The core spec carries what every archetype shares (navigator, l10n
// strings, BDD). `options` carries the SR wiring, validated here. What the
// templates do not own is hand-written (`owned:`): the domain's API, DTOs,
// mappers, results and facets models, the repository and the results
// widgets. Each module names those files and classes in `options.files` and
// `options.results`; a first write of `options.skeleton` writes working
// ones (paged only).

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:yaml/yaml.dart';

/// Thrown by [SrModel.parse] for options it cannot read; lint reports them.
class SrError implements Exception {
  SrError(this.path, this.message);

  final String path;
  final String message;
}

enum SrMode { paged, grouped }

/// An id extension type of the navigator's arguments.
class SrId {
  const SrId(this.name, this.type, this.doc);

  final String name;
  final String type;
  final String? doc;

  String get file => '${snakeCase(name)}.dart';
}

/// A server-side facet of a paged search (`sort`, `team`): a field of the
/// facets class and the bloc event that changes it.
class SrFacet {
  const SrFacet({
    required this.name,
    required this.type,
    required this.event,
    this.doc,
  });

  /// The facets class's field (`sort`).
  final String name;

  /// Its type, `?` when a facet can be unset (`String?`).
  final String type;

  /// The event factory (`sortChanged`).
  final String event;
  final String? doc;

  String get caseClass => '_${pascalCase(event)}';
  String get setter => 'with${pascalCase(name)}';
}

/// A group's hit class and the navigator method that opens it.
class SrHit {
  const SrHit(this.hitClass, this.calls);

  final String hitClass;
  final String calls;
}

class SrModel {
  SrModel._(this.spec);

  final ModuleSpec spec;

  late final SrMode mode;
  late final String item;
  late final String items;
  late final List<SrId> ids;
  late final int minLength;
  late final int debounceMs;
  late final int openGuardMs;
  late final String historyKey;
  late final int historyCap;
  late final bool trimQuery;
  late final String pageName;
  late final String? screenFile;
  late final String? screenConst;
  late final Map<String, String> files;
  late final Map<String, String> names;
  late final Map<String, String> prose;
  late final bool skeleton;

  /// ARB metadata with placeholders on lines of their own.
  late final bool arbBlock;

  // paged
  late final String entity;
  late final int pageSize;
  late final String pageSizeConst;
  late final List<SrFacet> facets;
  late final String openCalls;
  late final String emptyMessage;

  // grouped
  late final String filterDefault;
  late final List<SrHit> hits;

  // tests
  late final Map<String, String> tests;
  late final Map<String, String> tags;

  bool get paged => mode == SrMode.paged;
  bool get grouped => mode == SrMode.grouped;

  // --- names ------------------------------------------------------------------
  String get module => spec.module;
  String get pascal => pascalCase(module);
  String get camel => camelCase(module);
  String get itemPascal => pascalCase(item.replaceAll(' ', '_'));
  String get itemCamel => camelCase(item.replaceAll(' ', '_'));
  String get itemsCamel => camelCase(items.replaceAll(' ', '_'));
  String get itemsPascal => pascalCase(items.replaceAll(' ', '_'));
  String get navigator => spec.navigator!.name;
  String get flow => '${pascal}Flow';
  String get flowState => '${pascal}FlowState';
  String get bloc => '${pascal}Bloc';
  String get event => '${pascal}Event';
  String get state => '${pascal}State';
  String get page => '${pascal}Page';
  String get repository => '${pascal}Repository';
  String get diInitializer => '${pascal}DIInitializer';
  String get diModule => '${pascal}Module';
  String get rootImports => '${camel}RootImports';
  String get l10nClass => '${pascal}L10n';

  /// A class or function a module's own files declare, by role (`facets`,
  /// `query`, `tile`, ...): `options.names`, with a default.
  String name(String role, [String? fallback]) =>
      names[role] ??
      fallback ??
      (throw SrError('options.names.$role', 'options.names needs "$role"'));

  /// The path under `lib/src/` of the file a role names (`entity`).
  String file(String role, [String? fallback]) =>
      files[role] ??
      fallback ??
      (throw SrError('options.files.$role', 'options.files needs "$role"'));

  /// The `package:` URI of a file under `lib/src/`.
  String uri(String underSrc) => 'package:$module/src/$underSrc';

  /// The l10n key of [suffix] (`Title` -> `charactersSearchTitle`).
  String key(String suffix) => '$camel$suffix';

  /// The prose of [slot]: the spec's `options.prose`, else [fallback].
  String text(String slot, String fallback) {
    _consulted.add(slot);
    return prose[slot] ?? fallback;
  }

  /// The prose of [slot], or null when the spec gives none.
  String? optionalText(String slot) {
    _consulted.add(slot);
    return prose[slot];
  }

  final _consulted = <String>{};

  /// `options.prose` slots no template asked for.
  List<String> get unusedProse => [
    for (final k in prose.keys)
      if (!_consulted.contains(k)) k,
  ]..sort();

  /// The AC tag a test name starts with, plus a space; empty when untagged.
  String tag(String slot) {
    final t = tags[slot];
    return t == null ? '' : '$t ';
  }

  /// The string [key] in the template locale.
  String en(String key) {
    final s = spec.l10n!.strings.firstWhere((s) => s.key == key);
    return s.text[spec.l10n!.locales.first]!;
  }

  // --- parsing ------------------------------------------------------------------

  static SrModel parse(ModuleSpec spec) {
    final m = SrModel._(spec);
    final r = _Reader(spec.options, 'options');
    r.only(const [
      'mode',
      'item',
      'items',
      'ids',
      'query',
      'history',
      'flow',
      'analytics',
      'files',
      'names',
      'results',
      'facets',
      'filter',
      'hits',
      'tests',
      'tags',
      'prose',
      'skeleton',
      'arb',
    ]);
    m.mode = switch (r.str('mode')) {
      'paged' => SrMode.paged,
      'grouped' => SrMode.grouped,
      final other => throw SrError(
        'options.mode',
        '"mode" must be paged or grouped, not "$other"',
      ),
    };
    m.item = r.str('item');
    m.items = r.str('items');
    m.ids = [
      for (final (i, n) in r.list('ids').indexed)
        () {
          final x = _Reader(n, 'options.ids[$i]')..only(const ['name', 'type', 'doc']);
          return SrId(x.str('name'), x.str('type'), x.optStr('doc'));
        }(),
    ];
    final q = r.child('query')..only(const ['min_length', 'debounce_ms', 'open_guard_ms']);
    m.minLength = q.optInt('min_length') ?? 1;
    m.debounceMs = q.optInt('debounce_ms') ?? 300;
    m.openGuardMs = q.optInt('open_guard_ms') ?? 500;
    final h = r.child('history')..only(const ['key', 'cap']);
    m.historyKey = h.str('key', '${spec.module}.history');
    m.historyCap = h.optInt('cap') ?? 10;
    final f = r.child('flow')..only(const ['trim_query', 'page_name']);
    m.trimQuery = f.boolean('trim_query');
    m.pageName = f.str('page_name', 'search');
    final a = r.child('analytics')..only(const ['file', 'const', 'screen']);
    m.screenFile = a.optStr('file');
    m.screenConst = a.optStr('const');
    m.files = r.strMap('files');
    m.names = r.strMap('names');
    m.tests = r.strMap('tests');
    m.tags = r.strMap('tags');
    m.prose = r.strMap('prose');
    m.skeleton = r.boolean('skeleton');
    m.arbBlock = switch (r.optStr('arb')) {
      null || 'inline' => false,
      'block_placeholders' => true,
      final other => throw SrError(
        'options.arb',
        '"arb" must be inline or block_placeholders, not "$other"',
      ),
    };
    final res = r.child('results');
    if (m.paged) {
      res.only(const ['entity', 'page_size', 'page_size_const', 'open', 'empty_message']);
      m.entity = res.str('entity');
      m.pageSize = res.integer('page_size');
      m.pageSizeConst = res.str('page_size_const', '${m.itemsCamel}${pascalCase(spec.module.split('_').last)}PageSize');
      m.openCalls = res.str('open');
      m.emptyMessage = res.str('empty_message');
      m.facets = [
        for (final (i, n) in r.list('facets').indexed)
          () {
            final x = _Reader(n, 'options.facets[$i]')..only(const ['name', 'type', 'event', 'doc']);
            final name = x.str('name');
            return SrFacet(
              name: name,
              type: x.str('type'),
              event: x.str('event', '${name}Changed'),
              doc: x.optStr('doc'),
            );
          }(),
      ];
      m.filterDefault = '';
      m.hits = const [];
    } else {
      res.only(const ['type', 'hit', 'filter']);
      m.entity = '';
      m.pageSize = 0;
      m.pageSizeConst = '';
      m.openCalls = '';
      m.emptyMessage = '';
      m.facets = const [];
      final fl = r.child('filter')..only(const ['default']);
      m.filterDefault = fl.str('default');
      m.hits = [
        for (final (i, n) in r.list('hits').indexed)
          () {
            final x = _Reader(n, 'options.hits[$i]')..only(const ['class', 'calls']);
            return SrHit(x.str('class'), x.str('calls'));
          }(),
      ];
    }
    return m;
  }

  /// Archetype lint: the options parse, and the names they use exist.
  static List<Diagnostic> lint(ModuleSpec spec) {
    final out = <Diagnostic>[];
    void err(String path, String message) => out.add(
      Diagnostic.at(
        spec.optionsNode ?? spec.node,
        code: 'search',
        message: message,
        file: spec.file,
        yamlPath: path,
      ),
    );
    if (spec.navigator == null) {
      out.add(
        Diagnostic.at(spec.node, code: 'search', message: 'search needs a navigator', file: spec.file, yamlPath: 'navigator'),
      );
    }
    if (spec.l10n == null) {
      out.add(
        Diagnostic.at(spec.node, code: 'search', message: 'search needs l10n strings', file: spec.file, yamlPath: 'l10n'),
      );
    }
    if (spec.bdd.isEmpty) {
      out.add(
        Diagnostic.at(spec.node, code: 'search', message: 'search needs at least one BDD feature', file: spec.file, yamlPath: 'bdd'),
      );
    }
    final SrModel m;
    try {
      m = parse(spec);
    } on SrError catch (e) {
      err(e.path, e.message);
      return out;
    }
    if (out.isNotEmpty) return out;
    final methods = {for (final o in spec.navigator!.outbound) o.name: o};
    void method(String name, String path) {
      final o = methods[name];
      if (o == null) {
        err(path, 'the navigator has no method "$name"');
      } else if (o.args.length != 1 || !m.ids.any((i) => i.name == o.args[0])) {
        err(path, 'navigator method "$name" must take one id type of options.ids');
      }
    }

    if (m.paged) {
      method(m.openCalls, 'options.results.open');
      if (m.facets.isEmpty && !m.skeleton) {
        // A paged search without facets is allowed: no facet events.
      }
    } else {
      for (final (i, h) in m.hits.indexed) {
        method(h.calls, 'options.hits[$i].calls');
      }
      if (m.hits.isEmpty) err('options.hits', 'a grouped search needs hits');
    }
    if (m.skeleton && !m.paged) {
      err('options.skeleton', 'a skeleton is written for paged searches only');
    }
    final strings = {
      for (final s in spec.l10n?.strings ?? const <L10nStringSpec>[]) s.key: s,
    };
    final locales = spec.l10n?.locales ?? const [];
    for (final k in m.requiredStrings) {
      if (!strings.containsKey(k)) {
        err('l10n.strings', 'search needs the string "$k"');
      }
    }
    if (locales.isNotEmpty && locales.first == 'en_XA') {
      err('l10n.locales', 'the template locale (the first) cannot be the pseudo-locale en_XA');
    }
    for (final s in strings.values) {
      for (final l in locales) {
        if (l != 'en_XA' && !s.text.containsKey(l)) {
          err('${s.path}.text', '"${s.key}" has no "$l" text');
        }
      }
      for (final l in s.text.keys) {
        if (!locales.contains(l)) {
          err('${s.path}.text', '"${s.key}" has "$l" text, but "$l" is not in l10n.locales');
        }
      }
    }
    return out;
  }

  /// Every l10n key the templates use.
  List<String> get requiredStrings => [
    for (final s in [
      'Title',
      'FieldLabel',
      'ClearQuery',
      'Searching',
      'EmptyTitle',
      'EmptyMessage',
      'ErrorTitle',
      'Recent',
      'ClearRecent',
      'ClearFailed',
      'NoRecent',
      if (paged) ...['Loading', 'LoadMoreFailed'],
    ])
      key(s),
  ];
}

/// Reads one options map, naming the YAML path in errors.
class _Reader {
  _Reader(this.value, this.path);

  final Object? value;
  final String path;

  Map<Object?, Object?>? get _map => value is Map ? value! as Map<Object?, Object?> : null;

  Never fail(String key, String message) =>
      throw SrError('$path.$key', message);

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

  int? optInt(String key) {
    final v = _value(key);
    if (v == null) return null;
    if (v is! int) fail(key, '"$key" must be an integer');
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

  List<Object?> list(String key) {
    final v = _value(key);
    if (v == null) return const [];
    if (v is! List) fail(key, '"$key" must be a list');
    return v;
  }

  _Reader child(String key) {
    final v = _value(key);
    if (v != null && v is! Map) fail(key, '"$key" must be a map');
    return _Reader(v, '$path.$key');
  }

  void only(List<String> keys) {
    for (final k in _map?.keys ?? const <Object?>[]) {
      if (!keys.contains('$k')) {
        throw SrError('$path.$k', 'unknown key "$k"');
      }
    }
  }

  Map<String, String> strMap(String key) {
    final c = child(key);
    return {
      for (final e in c._map?.entries ?? const <MapEntry<Object?, Object?>>[])
        '${e.key}': '${e.value}',
    };
  }
}

// ignore: unused_element
typedef _Unused = YamlNode;
