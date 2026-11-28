// The section-detail (SC) archetype's model (plan 01 section 3.3, P2-05,
// T-0072): one entity's page in sections, with a favourite that signs in when
// needed, hand-overs to the app through the navigator, and optionally a
// second request that fills a section (related items), an inner page inside
// the flow (a cover) and analytics for a saved favourite.
//
// The core spec carries what every archetype shares (navigator, l10n strings,
// BDD). `options` carries the SC wiring, validated here. Names follow from
// the module name, `item`/`items` and the class `prefix`, so a spec states
// each fact once; what the two exemplars write differently is an option or a
// prose slot.

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/options_reader.dart';
import 'package:yaml/yaml.dart';

/// An id extension type.
class ScId {
  const ScId(this.name, this.type, this.doc);

  final String name;
  final String type;
  final String? doc;

  String get file => '${snakeCase(name)}.dart';
}

/// A hand-over: an event of the details bloc that leaves the feature through
/// a navigator method with a target's id.
class ScOpen {
  const ScOpen({
    required this.calls,
    required this.id,
    required this.label,
    required this.eventDoc,
    this.lookup,
    this.lookupParam = 'name',
    this.lookupParamType = 'String',
    this.idField = 'id',
    this.field,
    this.idLocal = false,
  });

  /// The navigator method, and the event's name (`openCharacter`).
  final String calls;

  /// The id type the navigator takes (`CharacterId`).
  final String id;

  /// What the target is called in a guard key and in step names
  /// (`character`, `creator`).
  final String label;

  /// The event factory's doc.
  final String? eventDoc;

  /// The test env's lookup of a fixture record by [lookupParam]
  /// (`characterNamed`), when the `the app was asked to open <label>` steps
  /// have a template for this open.
  final String? lookup;
  final String lookupParam;
  final String lookupParamType;
  final String idField;

  /// The entity field that holds the target's id (the owned skeleton page
  /// shows a button that opens it).
  final String? field;

  /// The `the app was asked to open` steps bind the id to a local first.
  final bool idLocal;

  String get pascal => pascalCase(calls);
}

/// A second request that fills a section of the page (the character's
/// comics), started with the primary one.
class ScRelated {
  const ScRelated({
    required this.name,
    required this.item,
    required this.summary,
    required this.pageDto,
    required this.path,
    required this.param,
    required this.limit,
  });

  /// The plural noun (`comics`): the fetch method is `fetch<Name>`.
  final String name;

  /// The singular noun (`comic`).
  final String item;

  /// The domain type of one entry (`ComicSummary`).
  final String summary;

  /// The DTO of the endpoint's page (`ComicsPageDto`; `results` holds them).
  final String pageDto;
  final String path;

  /// The endpoint's query parameter that takes the item's id.
  final String param;
  final int limit;

  String get pascal => pascalCase(name);
  String get camel => camelCase(name);
}

/// An inner page of the flow that the page opens (the cover): an event, a
/// flow state field holding the shown entity, and a flow page.
class ScCover {
  const ScCover({
    required this.field,
    required this.event,
    required this.page,
    required this.pageName,
  });

  /// The flow state's field (`cover`).
  final String field;

  /// The details event (`openCover`).
  final String event;

  /// The page widget (`ComicCoverPage`).
  final String page;

  /// The flow page's name (`cover`).
  final String pageName;

  String get pageFile => '${snakeCase(page)}.dart';
}

/// Analytics for a saved favourite, over `AnalyticsTracker`.
class ScAnalytics {
  const ScAnalytics({
    required this.event,
    required this.screen,
    required this.screenConst,
    required this.eventConst,
    required this.method,
    required this.extension,
  });

  /// The event's name (`character_favourited`).
  final String event;

  /// The screen the flow's one page is (`character_details`).
  final String screen;
  final String screenConst;
  final String eventConst;

  /// The tracker extension's method (`characterFavourited`).
  final String method;
  final String extension;
}

/// A contract test target in BUILD (the file is hand-written).
class ScContract {
  const ScContract({
    required this.name,
    required this.main,
    required this.comment,
    required this.deps,
  });

  final String name;
  final String main;
  final String comment;
  final List<String> deps;
}

class ScTests {
  const ScTests({
    required this.fixtureSets,
    required this.userEmail,
    required this.tags,
    required this.legacyGoldens,
    required this.contracts,
    required this.flowScopeTags,
    required this.env,
    required this.factsKey,
    required this.plainFacts,
    required this.minPure,
    required this.tracked,
  });

  /// Fixture sets the owned skeleton env's `bddSetUpAll` registers.
  final List<String> fixtureSets;
  final String userEmail;

  /// Test slot -> the AC id its name starts with.
  final Map<String, String> tags;
  final bool legacyGoldens;
  final List<ScContract> contracts;
  final Map<String, String> flowScopeTags;

  /// What the owned env's first write needs.
  final Map<String, String> env;

  /// The env's key of the facts section (`comicFactsKey`).
  final String factsKey;

  /// The facts step compares text with non-breaking spaces as plain ones.
  final bool plainFacts;

  /// The architecture test's `greaterThan(n)` of generator-read files.
  final int minPure;

  /// The step that checks the analytics event (analytics only).
  final bool tracked;
}

class ScModel {
  ScModel._(this.spec);

  final ModuleSpec spec;

  late final String item;
  late final String items;
  late final String prefix;
  late final String scroll;
  late final List<ScId> ids;
  late final String entity;
  late final String titleField;
  late final String dto;
  late final String itemPath;
  late final String favouritePath;
  late final String description;
  late final List<ScOpen> opens;
  late final ScRelated? related;
  late final ScCover? cover;
  late final ScAnalytics? analytics;
  late final ScTests tests;
  late final Map<String, String> prose;

  /// Packages BUILD lists beyond what the generated files use (the exemplars'
  /// owned files use more): `_PURE_DEPS`, `_TEST_DEPS`, and what the
  /// flow-scope test target lists itself.
  late final List<String> buildPure;
  late final List<String> buildTests;
  late final List<String> buildFlowScope;

  // --- names ------------------------------------------------------------------
  String get module => spec.module;
  String get itemPascal => pascalCase(item);
  String get itemCamel => camelCase(item);

  /// The item as prose reads it (`story_arc` -> `story arc`).
  String get itemWords => item.replaceAll('_', ' ');

  /// The primitive type of the item's id (`int`, `String`).
  String get idPrim => ids.first.type;

  /// The primitive type of the id [name].
  String idPrimOf(String name) =>
      ids.firstWhere((i) => i.name == name, orElse: () => ids.first).type;
  String get itemsCamel => camelCase(items);
  String get itemsPascal => pascalCase(items);
  String get prefixCamel => camelCase(prefix);
  String get itemId => ids.first.name;
  String get idArg => '${itemCamel}Id';

  String get navigator => spec.navigator!.name;
  String get flow => '${prefix}Flow';
  String get flowState => '${prefix}FlowState';
  String get api => '${prefix}Api';
  String get repository => '${prefix}Repository';
  String get diInitializer => '${prefix}DIInitializer';
  String get rootImports => '${prefixCamel}RootImports';
  String get l10nClass => '${prefix}L10n';
  String get detailsBloc => '${itemPascal}DetailsBloc';
  String get detailsEvent => '${itemPascal}DetailsEvent';
  String get detailsState => '${itemPascal}DetailsState';
  String get detailsPage => '${itemPascal}DetailsPage';
  String get favouriteBloc => '${itemPascal}FavouriteBloc';
  String get favouriteEvent => '${itemPascal}FavouriteEvent';
  String get favouriteState => '${itemPascal}FavouriteState';
  String get detailsBodyKey => '${itemCamel}DetailsBodyKey';
  String get dtoFile => '${snakeCase(entity)}_dto.dart';
  String get mapperFile => '${snakeCase(entity)}_mapper.dart';
  String get entityFile => '${snakeCase(entity)}.dart';
  String get navigatorMock => 'Mock$navigator';

  /// The l10n key of [suffix] (`Title` -> `comicsDetailsTitle`).
  String key(String suffix) => '$prefixCamel$suffix';

  /// The id type of the item.
  String get itemIdType => ids.first.name;

  /// `comic`'s kind on the favourites endpoints.
  late final String favouriteKind;

  // --- the test env's names (an owned file; the steps use these) -----------
  String get envFile => 'test/feature/util/${module}_env.dart';
  String get envNavigator => '${itemsCamel}Navigator';
  String get envContainer => 'ensure${itemsPascal}Container';
  String get envHost => '${itemsCamel}TestHost';
  String get envUnderTest => '${prefixCamel}FlowUnderTest';
  String get envPageKey => '${itemCamel}PageKey';
  String get envScrollable => '${itemCamel}BodyScrollable';
  String get envScrollUntil => 'scroll${itemPascal}UntilVisible';
  String get envTap => 'tap${itemPascal}Target';
  String get envFlowState => '${itemsCamel}FlowState';

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
    final t = tests.tags[slot];
    return t == null ? '' : '$t ';
  }

  // --- parsing ------------------------------------------------------------------

  /// Reads `spec.options`. Throws [OptionsError] on the first problem.
  static ScModel parse(ModuleSpec spec) {
    final m = ScModel._(spec);
    final r = OptionsReader(spec.optionsNode, 'options');
    m.item = r.str('item');
    m.items = r.str('items');
    m.prefix = r.str('prefix', pascalCase(spec.module));
    m.scroll = r.str('scroll', m.item);
    m.ids = r.items('ids', (x) {
      return ScId(x.str('name'), x.str('type'), x.optStr('doc'));
    });
    m.entity = r.str('entity', pascalCase(m.item));
    m.titleField = r.str('title', 'title');
    m.dto = r.str('dto', '${m.entity}Dto');
    m.itemPath = r.str('item_path');
    m.favouriteKind = r.str('favourite_kind', m.item);
    m.favouritePath = r.str(
      'favourite_path',
      'v1/me/favourites/${m.favouriteKind}/{id}',
    );
    m.description = spec.description ?? '';
    m.opens = r.items('opens', (x) {
      final calls = x.str('calls');
      x.only(const [
        'calls',
        'id',
        'label',
        'event_doc',
        'lookup',
        'lookup_param',
        'lookup_param_type',
        'id_field',
        'field',
        'id_local',
      ]);
      return ScOpen(
        calls: calls,
        id: x.str('id'),
        label: x.str('label'),
        eventDoc: x.optStr('event_doc'),
        lookup: x.optStr('lookup'),
        lookupParam: x.str('lookup_param', 'name'),
        lookupParamType: x.str('lookup_param_type', 'String'),
        idField: x.str('id_field', 'id'),
        field: x.optStr('field'),
        idLocal: x.boolean('id_local'),
      );
    });
    final rel = r.child('related');
    m.related = !rel.isPresent
        ? null
        : () {
            rel.only(const [
              'name',
              'item',
              'summary',
              'page_dto',
              'path',
              'param',
              'limit',
            ]);
            return ScRelated(
              name: rel.str('name'),
              item: rel.str('item'),
              summary: rel.str('summary'),
              pageDto: rel.str('page_dto'),
              path: rel.str('path'),
              param: rel.str('param'),
              limit: rel.integer('limit'),
            );
          }();
    final cov = r.child('cover');
    m.cover = !cov.isPresent
        ? null
        : () {
            cov.only(const ['field', 'event', 'page', 'page_name']);
            return ScCover(
              field: cov.str('field', 'cover'),
              event: cov.str('event', 'openCover'),
              page: cov.str('page', '${m.itemPascal}CoverPage'),
              pageName: cov.str('page_name', 'cover'),
            );
          }();
    final an = r.child('analytics');
    m.analytics = !an.isPresent
        ? null
        : () {
            an.only(const ['event', 'screen', 'method']);
            final event = an.str('event', '${m.item}_favourited');
            final screen = an.str('screen', '${m.item}_details');
            return ScAnalytics(
              event: event,
              screen: screen,
              screenConst: '${m.itemCamel}DetailsScreen',
              eventConst: '${m.itemCamel}FavouritedEvent',
              method: an.str('method', '${m.itemCamel}Favourited'),
              extension: '${m.itemPascal}Tracking',
            );
          }();
    final t = r.child('tests');
    m.tests = ScTests(
      fixtureSets: t.strList('fixture_sets'),
      userEmail: t.str('user_email', 'reader@mini-client.test'),
      tags: t.strMap('tags'),
      legacyGoldens: t.boolean('legacy_goldens'),
      contracts: t.items(
        'contracts',
        (x) => ScContract(
          name: x.str('name'),
          main: x.str('main'),
          comment: x.str('comment'),
          deps: x.strList('deps'),
        ),
      ),
      flowScopeTags: t.strMap('flow_scope_tags'),
      env: t.strMap('env'),
      factsKey: t.str('facts_key', '${m.itemCamel}FactsKey'),
      plainFacts: t.boolean('plain_facts'),
      minPure: t.integer('min_pure', 10),
      tracked: t.boolean('tracked'),
    );
    final b = r.child('build');
    m.buildPure = b.strList('pure');
    m.buildTests = b.strList('tests');
    m.buildFlowScope = b.has('flow_scope')
        ? b.strList('flow_scope')
        : const ['mc_monitoring', 'mc_test_utils', 'flutter', 'flutter_test'];
    b.only(const ['pure', 'tests', 'flow_scope']);
    m.prose = r.strMap('prose');
    r.only(const [
      'build',
      'item',
      'items',
      'prefix',
      'scroll',
      'ids',
      'entity',
      'title',
      'dto',
      'item_path',
      'favourite_path',
      'favourite_kind',
      'opens',
      'related',
      'cover',
      'analytics',
      'tests',
      'prose',
    ]);
    t.only(const [
      'fixture_sets',
      'user_email',
      'tags',
      'legacy_goldens',
      'contracts',
      'flow_scope_tags',
      'env',
      'facts_key',
      'plain_facts',
      'min_pure',
      'tracked',
    ]);
    return m;
  }

  /// Archetype lint: the options parse, and the names they use exist.
  static List<Diagnostic> lint(ModuleSpec spec) {
    final out = <Diagnostic>[];
    void err(YamlNode? node, String path, String message) => out.add(
      Diagnostic.at(
        node ?? spec.node,
        code: 'section_detail',
        message: message,
        file: spec.file,
        yamlPath: path,
      ),
    );
    if (spec.navigator == null) {
      err(spec.node, 'navigator', 'section_detail needs a navigator');
    }
    if (spec.l10n == null) {
      err(spec.node, 'l10n', 'section_detail needs l10n strings');
    }
    if (spec.bdd.isEmpty) {
      err(spec.node, 'bdd', 'section_detail needs at least one BDD feature');
    }
    if (spec.description == null) {
      err(spec.node, 'description', 'section_detail needs a description');
    }
    final ScModel m;
    try {
      m = parse(spec);
    } on OptionsError catch (e) {
      err(e.node, e.path, e.message);
      return out;
    } on FormatException catch (e) {
      err(spec.optionsNode, 'options', e.message);
      return out;
    }
    if (out.isNotEmpty) return out;
    final methods = {for (final o in spec.navigator!.outbound) o.name: o};
    final entities = {for (final e in spec.entities) e.name: e};
    void needEntity(String name, String path, {bool dto = false}) {
      final e = entities[name];
      if (e == null) {
        err(spec.optionsNode, path, 'no entity "$name" in entities');
      } else if (dto != (e.json == true)) {
        err(
          spec.optionsNode,
          path,
          dto
              ? '"$name" must be a DTO: add `json: true`'
              : '"$name" is a DTO (`json: true`), but a domain entity is needed',
        );
      }
    }

    needEntity(m.entity, 'options.entity');
    needEntity(m.dto, 'options.dto', dto: true);
    if (m.related case final r?) {
      needEntity(r.summary, 'options.related.summary');
      needEntity(r.pageDto, 'options.related.page_dto', dto: true);
    }
    final entity = entities[m.entity];
    if (entity != null) {
      if (!entity.fields.any((f) => f.name == m.titleField)) {
        err(
          spec.optionsNode,
          'options.title',
          '"${m.entity}" has no field "${m.titleField}"',
        );
      }
      for (final (i, o) in m.opens.indexed) {
        final f = o.field;
        if (f != null && !entity.fields.any((x) => x.name == f)) {
          err(
            spec.optionsNode,
            'options.opens[$i].field',
            '"${m.entity}" has no field "$f"',
          );
        }
      }
    }
    if (m.ids.isEmpty) {
      err(spec.optionsNode, 'options.ids', 'the first id is the item\'s');
    }
    final signIn = methods['requestSignIn'];
    if (signIn == null || signIn.args.isNotEmpty || signIn.returns == null) {
      err(
        spec.optionsNode,
        'navigator.outbound',
        'the navigator needs requestSignIn() -> bool: the favourite signs in',
      );
    }
    for (final (i, o) in m.opens.indexed) {
      final n = methods[o.calls];
      if (n == null) {
        err(
          spec.optionsNode,
          'options.opens[$i].calls',
          'the navigator has no method "${o.calls}"',
        );
      } else if (n.args.length != 1 || n.args[0] != o.id) {
        err(
          spec.optionsNode,
          'options.opens[$i].id',
          'navigator method "${o.calls}" must take exactly one ${o.id}',
        );
      }
      if (!m.ids.any((x) => x.name == o.id)) {
        err(
          spec.optionsNode,
          'options.opens[$i].id',
          '"${o.id}" is not one of options.ids',
        );
      }
    }
    final strings = {
      for (final s in spec.l10n?.strings ?? const <L10nStringSpec>[]) s.key: s,
    };
    final locales = spec.l10n?.locales ?? const [];
    for (final k in m.requiredStrings) {
      if (!strings.containsKey(k)) {
        err(spec.node, 'l10n.strings', 'section_detail needs the string "$k"');
      }
    }
    if (locales.isNotEmpty && locales.first == 'en_XA') {
      err(
        spec.l10n!.node,
        'l10n.locales',
        'the template locale (the first) cannot be the pseudo-locale en_XA',
      );
    }
    for (final s in strings.values) {
      for (final l in locales) {
        if (l != 'en_XA' && !s.text.containsKey(l)) {
          err(s.node, '${s.path}.text', '"${s.key}" has no "$l" text');
        }
      }
      for (final l in s.text.keys) {
        if (!locales.contains(l)) {
          err(
            s.node,
            '${s.path}.text',
            '"${s.key}" has "$l" text, but "$l" is not in l10n.locales',
          );
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
      'NotFoundTitle',
      'NotFoundMessage',
      'ErrorTitle',
      'FavouriteAdd',
      'FavouriteRemove',
      'FavouriteLoadFailed',
      'FavouriteSaveFailed',
    ])
      key(s),
    for (final o in opens)
      if (o.field != null) key('Open${pascalCase(o.label)}'),
  ];
}
