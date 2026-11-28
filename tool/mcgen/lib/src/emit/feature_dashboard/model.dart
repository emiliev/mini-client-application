// The dashboard (DB) archetype's model (plan 01 section 3.3, P2-06; ADR-0017).
//
// A dashboard page is N independent sections: each has its own bloc (and
// sealed events and freezed state) on one shared base, loads in parallel
// when the page is first shown, fails and retries on its own, and is viewed
// once per visit. The page decides which sections exist from feature flags,
// read once per visit. An optional detail page (a category's products) is a
// page of the same flow, paged. A section may depend on the session (the
// cart): it reloads once per session epoch.
//
// The core spec carries what every archetype shares (navigator, l10n
// strings, BDD). `options` carries the DB wiring, validated here. What the
// templates do not own is hand-written (`owned:`): the domain (API, DTOs,
// mapper, models, repository), the section widgets, the detail page, the
// test env, the contract and flow-scope tests and BUILD.bazel.

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/options_reader.dart';

/// What a section's bloc depends on, beyond the repository, the analytics
/// port and monitoring, in constructor order.
enum DbUse { flow, navigator, clock, session }

enum DbKind { list, session }

/// An id extension type of the navigator's arguments or the flow's.
class DbId {
  const DbId(this.name, this.type, this.doc);

  final String name;
  final String type;
  final String? doc;

  String get file => '${snakeCase(name)}.dart';
}

/// A feature flag a section depends on.
class DbFlag {
  const DbFlag({
    required this.name,
    required this.key,
    required this.defaultValue,
    required this.description,
    required this.doc,
  });

  /// The Dart constant (`storeHomeFeatured`).
  final String name;

  /// The remote key (`store.home_featured`).
  final String key;
  final bool defaultValue;
  final String description;
  final String? doc;
}

class DbSection {
  DbSection({
    required this.name,
    required this.kind,
    required this.item,
    required this.data,
    required this.readyParams,
    required this.readyArgs,
    required this.emptyWhen,
    required this.fetch,
    required this.fetchMethod,
    required this.uses,
    required this.top,
    required this.arg,
    required this.argType,
    required this.openDefault,
    required this.members,
    required this.flag,
    required this.blocName,
    required this.widget,
    required this.openId,
    required this.openCall,
    required this.openKind,
  });

  /// The section's name: the analytics `section`, the widget key part and
  /// the l10n key part (`banners`).
  final String name;
  final DbKind kind;

  /// The type the tap event carries (`StoreBanner`).
  final String item;

  /// What `fetch` answers (`List<StoreBanner>`).
  final String data;

  /// The `ready` state's parameters and the arguments the bloc passes it.
  final String readyParams;
  final String readyArgs;

  /// The expression on `data` that makes the section empty.
  final String emptyWhen;

  /// The repository method `fetch` calls, or the whole method as written.
  final String? fetch;
  final String? fetchMethod;
  final Set<DbUse> uses;

  /// Declarations written above the bloc's doc (a typedef).
  final String? top;

  /// The tap event's argument (`banner`) and its type.
  final String arg;
  final String argType;

  /// The tap's keep-region defaults, and members written after the handler
  /// (a helper method), also a keep region.
  final String openDefault;
  final String? members;

  /// The flag that must be on for the section to exist.
  final DbFlag? flag;
  final String blocName;

  /// The section's own widget class and file stem (`BannersSection`).
  final String widget;

  // session sections only: what a tap hands over, and the analytics id
  final String openId;
  final String openCall;
  final String openKind;

  String get pascal => pascalCase(name);
  String get camel => camelCase(name);
  String get snake => snakeCase(blocName);
  String get bloc => '${blocName}Bloc';
  String get event => '${blocName}Event';
  String get state => '${blocName}State';
  bool get isSession => kind == DbKind.session;
  bool get hasKeepOpen => !isSession;
}

/// The paged detail page inside the flow (a category's products).
class DbDetail {
  DbDetail({
    required this.name,
    required this.id,
    required this.item,
    required this.items,
    required this.fetchPage,
    required this.lookup,
    required this.openCall,
    required this.openKind,
    required this.pageSize,
    required this.pageSizeDoc,
  });

  /// `category`: the flow state's field, `OpenCategory`, `openCategory`,
  /// `<Name>Page`, the analytics value `<name>Products`.
  final String name;

  /// The id type (`CategoryId`).
  final String id;
  final String item;

  /// `products`: `<Name>ProductsBloc`.
  final String items;
  final String fetchPage;
  final String lookup;
  final String openCall;
  final String openKind;
  final int pageSize;
  final String? pageSizeDoc;

  String get pascal => pascalCase(name);
  String get open => 'Open$pascal';
  String get bloc => '$pascal${pascalCase(items)}Bloc';
  String get arg => camelCase(item);
  String get stem => snakeCase('$pascal${pascalCase(items)}');
  String get blocBase => '${stem}_bloc';
  String get event => '$pascal${pascalCase(items)}Event';
  String get state => '$pascal${pascalCase(items)}State';
  String get analytics => '$name${pascalCase(items)}';
}

class DbError implements Exception {
  DbError(this.node, this.path, this.message);

  final Object? node;
  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

class DbModel {
  DbModel._(this.spec);

  final ModuleSpec spec;

  late final String prefix;
  late final List<DbSection> sections;
  late final List<DbFlag> flags;
  late final DbDetail? detail;
  late final List<DbId> ids;
  late final List<String> kinds;
  late final String modelFile;
  late final String l10nFile;
  late final List<String> barrel;
  late final Map<String, String> params;
  late final Map<String, String> prose;
  late final Map<String, String> tests;
  late final String screenHome;
  late final String? screenDetail;
  late final String reposName;

  // --- names --------------------------------------------------------------
  String get module => spec.module;
  String get pascal => pascalCase(module);
  String get camel => camelCase(module);
  String get k => prefix;
  String get kSnake => snakeCase(prefix);
  String get kCamel => camelCase(prefix);
  String get navigator => spec.navigator!.name;
  String get flow => '${pascal}Flow';
  String get flowState => '${pascal}FlowState';
  String get repository => '${pascal}Repository';
  String get diInitializer => '${pascal}DIInitializer';
  String get rootImports => '${camel}RootImports';
  String get l10nClass => '${pascal}L10n';
  String get l10nExt => '${kCamel}L10n';
  String get section => '${prefix}Section';
  String get sectionBloc => '${prefix}SectionBloc';
  String get itemKind => '${prefix}ItemKind';
  String get tracking => '${prefix}Tracking';
  String get clock => '${prefix}Clock';
  String get analyticsFile => '${kSnake}_analytics.dart';
  String get clockFile => '${kSnake}_clock.dart';
  String get sectionBlocFile => '${kSnake}_section_bloc.dart';
  String get homePage => '${pascal}Page';
  String get homeContent => '_${pascal}Content';
  String get bodyKey => '${camel}BodyKey';
  String get viewedEvent => '${kSnake}_section_viewed';
  String get tappedEvent => '${kSnake}_item_tapped';
  bool get hasSession => sections.any((s) => s.uses.contains(DbUse.session));
  bool get hasClock => sections.any((s) => s.uses.contains(DbUse.clock));
  bool get hasFlow => sections.any((s) => s.uses.contains(DbUse.flow));

  String uri(String underSrc) => 'package:$module/src/$underSrc';

  /// The l10n key of [suffix] (`Title` -> `storeHomeTitle`).
  String key(String suffix) => '$camel$suffix';

  /// The id of [typeName], or null.
  DbId? idOf(String typeName) {
    for (final i in ids) {
      if (i.name == typeName) return i;
    }
    return null;
  }

  /// Method parameter name of a navigator call.
  String param(String method) => params[method] ?? 'id';

  String get detailBlocImport =>
      detail == null ? '' : 'presentation/bloc/${detail!.blocBase}.dart';

  // --- prose --------------------------------------------------------------
  final _consulted = <String>{};

  /// The prose of [slot]: the spec's `options.prose`, else [fallback].
  String text(String slot, String fallback) {
    _consulted.add(slot);
    return prose[slot] ?? fallback;
  }

  /// The prose of [slot], or null when the spec gives none (or an empty
  /// one: a slot set to `""` removes a doc).
  String? optionalText(String slot) {
    _consulted.add(slot);
    final v = prose[slot];
    return v == null || v.isEmpty ? null : v;
  }

  /// The raw text of [slot] (the spec's, else [fallback]); null when the
  /// spec sets the slot to an empty string, which removes a doc.
  String? docText(String slot, String? fallback) {
    _consulted.add(slot);
    final v = prose.containsKey(slot) ? prose[slot] : fallback;
    return v == null || v.isEmpty ? null : v.trimRight();
  }

  /// The doc of [slot] as `/// ` lines ending in a newline, or nothing.
  String doc(String slot, String? fallback) {
    final v = docText(slot, fallback);
    if (v == null) return '';
    return '${v.split('\n').map((l) => l.isEmpty ? '///' : '/// $l').join('\n')}\n';
  }

  /// The doc of [slot] for a member of a class, written where the template
  /// has `  <<slot>>member`: the first line follows the template's indent, so
  /// every later line (and the member after the doc) is indented by two.
  String memberDoc(String slot, String? fallback) {
    final v = docText(slot, fallback);
    if (v == null) return '';
    return '${v.split('\n').map((l) => l.isEmpty ? '///' : '/// $l').join('\n  ')}\n  ';
  }

  List<String> get unusedProse => [
    for (final k in prose.keys)
      if (!_consulted.contains(k)) k,
  ]..sort();

  /// The string [key] in the template locale.
  String en(String key) {
    final s = spec.l10n!.strings.firstWhere((s) => s.key == key);
    return s.text[spec.l10n!.locales.first]!;
  }

  // --- parsing ------------------------------------------------------------

  static const _sectionKeys = [
    'name',
    'kind',
    'item',
    'data',
    'bloc',
    'widget',
    'ready_params',
    'ready_args',
    'empty_when',
    'fetch',
    'fetch_method',
    'uses',
    'top',
    'arg',
    'open',
    'members',
    'flag',
    'open_id',
    'open_call',
    'open_kind',
  ];

  static DbModel parse(ModuleSpec spec) {
    final m = DbModel._(spec);
    final r = OptionsReader(spec.optionsNode, 'options')
      ..only(const [
        'prefix',
        'model_file',
        'l10n_file',
        'sections',
        'flags',
        'detail',
        'ids',
        'kinds',
        'barrel',
        'params',
        'screens',
        'tests',
        'prose',
      ]);
    m.prefix = r.str('prefix');
    m.modelFile = r.str('model_file', '${snakeCase(m.prefix)}.dart');
    m.l10nFile = r.str(
      'l10n_file',
      'presentation/widget/${snakeCase(m.prefix)}_section.dart',
    );
    m.kinds = r.strList('kinds');
    m.barrel = r.strList('barrel');
    m.params = r.strMap('params');
    m.tests = r.strMap('tests');
    m.prose = r.strMap('prose');
    m.ids = r.items('ids', (x) {
      x.only(const ['name', 'type', 'doc']);
      return DbId(x.str('name'), x.str('type'), x.optStr('doc'));
    });
    final screens = r.child('screens')..only(const ['home', 'detail']);
    m.screenHome = screens.str('home', m.module);
    m.screenDetail = screens.optStr('detail');
    m.reposName = m.repository;
    m.flags = r.items('flags', (x) {
      x.only(const ['name', 'key', 'default', 'description', 'doc']);
      return DbFlag(
        name: x.str('name'),
        key: x.str('key'),
        defaultValue: x.boolean('default'),
        description: x.str('description'),
        doc: x.optStr('doc'),
      );
    });
    final flagByName = {for (final f in m.flags) f.name: f};
    if (r.child('detail').isPresent) {
      final d = r.child('detail')
        ..only(const [
          'name',
          'id',
          'item',
          'items',
          'fetch_page',
          'lookup',
          'open_call',
          'open_kind',
          'page_size',
          'page_size_doc',
        ]);
      m.detail = DbDetail(
        name: d.str('name'),
        id: d.str('id'),
        item: d.str('item'),
        items: d.str('items'),
        fetchPage: d.str('fetch_page'),
        lookup: d.str('lookup'),
        openCall: d.str('open_call'),
        openKind: d.str('open_kind'),
        pageSize: d.integer('page_size'),
        pageSizeDoc: d.optStr('page_size_doc'),
      );
    } else {
      m.detail = null;
    }
    m.sections = r.items('sections', (x) {
      x.only(_sectionKeys);
      final name = x.str('name');
      final kind = switch (x.str('kind', 'list')) {
        'list' => DbKind.list,
        'session' => DbKind.session,
        final other => x.fail(
          'kind',
          '"kind" must be list or session, not "$other"',
        ),
      };
      final uses = <DbUse>{
        for (final u in x.strList('uses'))
          DbUse.values.firstWhere(
            (e) => e.name == u,
            orElse: () => x.fail(
              'uses',
              '"uses" has "$u": it must be flow, navigator, clock or session',
            ),
          ),
      };
      final flagName = x.optStr('flag');
      if (flagName != null && !flagByName.containsKey(flagName)) {
        x.fail('flag', 'options.flags has no flag "$flagName"');
      }
      final item = x.str('item');
      final blocName = x.str('bloc', pascalCase(name));
      final data = x.str('data', 'List<$item>');
      return DbSection(
        name: name,
        kind: kind,
        item: item,
        data: data,
        readyParams: x.str('ready_params', '$data $name'),
        readyArgs: x.str('ready_args', 'data'),
        emptyWhen: x.str('empty_when', 'data.isEmpty'),
        fetch: x.optStr('fetch'),
        fetchMethod: x.optStr('fetch_method'),
        uses: uses,
        top: x.optStr('top'),
        arg: x.str('arg', camelCase(item)),
        argType: item,
        openDefault: x.optStr('open') ?? '',
        members: x.optStr('members'),
        flag: flagName == null ? null : flagByName[flagName],
        blocName: blocName,
        widget: x.str('widget', '${pascalCase(name)}Section'),
        openId: x.optStr('open_id') ?? 'summary',
        openCall: x.optStr('open_call') ?? '',
        openKind: x.optStr('open_kind') ?? '',
      );
    });
    return m;
  }

  /// Archetype lint: the options parse, every role the emitters read is
  /// present and consistent, and the names they use exist. Errors name the
  /// YAML path.
  static List<Diagnostic> lint(ModuleSpec spec) {
    final out = <Diagnostic>[];
    void err(String path, String message) => out.add(
      Diagnostic.at(
        spec.optionsNode ?? spec.node,
        code: 'dashboard',
        message: message,
        file: spec.file,
        yamlPath: path,
      ),
    );
    if (spec.navigator == null) {
      err('navigator', 'a dashboard needs a navigator');
    }
    if (spec.l10n == null) err('l10n', 'a dashboard needs l10n strings');
    if (spec.bdd.isEmpty)
      err('bdd', 'a dashboard needs at least one BDD feature');
    if (spec.description == null) {
      err('description', 'a dashboard needs a description (the pubspec)');
    }
    if (out.isNotEmpty) return out;
    final DbModel m;
    try {
      m = parse(spec);
    } on OptionsError catch (e) {
      out.add(
        Diagnostic.at(
          e.node,
          code: 'dashboard',
          message: e.message,
          file: spec.file,
          yamlPath: e.path,
        ),
      );
      return out;
    }
    if (m.sections.length < 2) {
      err('options.sections', 'a dashboard needs at least two sections');
    }
    final names = <String>{};
    for (final (i, s) in m.sections.indexed) {
      final p = 'options.sections[$i]';
      if (!names.add(s.name)) err('$p.name', 'duplicate section "${s.name}"');
      if (s.fetch == null && s.fetchMethod == null) {
        err(p, 'section "${s.name}" needs "fetch" or "fetch_method"');
      }
      if (s.fetch != null && s.fetchMethod != null) {
        err(p, 'section "${s.name}" has both "fetch" and "fetch_method"');
      }
      if (s.isSession) {
        if (!s.uses.contains(DbUse.session) ||
            !s.uses.contains(DbUse.navigator)) {
          err(
            '$p.uses',
            'a session section uses session and navigator',
          );
        }
        for (final (k, v) in [
          ('open_call', s.openCall),
          ('open_kind', s.openKind),
        ]) {
          if (v.isEmpty) err('$p.$k', 'a session section needs "$k"');
        }
        if (s.fetch == null) {
          err(
            '$p.fetch',
            'a session section needs "fetch": the repository method that '
                'takes the session epoch',
          );
        }
      } else {
        if (s.openDefault.isEmpty) {
          err('$p.open', 'section "${s.name}" needs "open": the tap handler');
        }
        if (s.uses.contains(DbUse.session)) {
          err('$p.uses', 'only a session section uses the session');
        }
      }
      if (s.uses.contains(DbUse.flow) && m.detail == null) {
        err(
          '$p.uses',
          'section "${s.name}" uses the flow, which holds only the detail '
              'page: options.detail is missing',
        );
      }
      for (final role
          in s.uses.contains(DbUse.navigator)
              ? const ['navigator']
              : const <String>[]) {
        if (spec.navigator == null) err('$p.uses', 'no $role');
      }
    }
    if (m.sections.every((s) => s.flag != null)) {
      err('options.sections', 'at least one section is not behind a flag');
    }
    if (m.hasClock && !m.sections.any((s) => s.uses.contains(DbUse.clock))) {
      err('options.sections', 'unreachable');
    }
    // flags
    final usedFlags = {
      for (final s in m.sections)
        if (s.flag != null) s.flag!.name,
    };
    for (final (i, f) in m.flags.indexed) {
      if (!usedFlags.contains(f.name)) {
        err('options.flags[$i]', 'flag "${f.name}" gates no section');
      }
    }
    // the detail page
    final d = m.detail;
    if (d != null) {
      if (m.idOf(d.id) == null) {
        err('options.detail.id', 'options.ids has no "${d.id}"');
      }
      if (m.screenDetail == null) {
        err('options.screens.detail', 'a detail page needs its screen name');
      }
      if (!m.kinds.contains(d.openKind)) {
        err(
          'options.detail.open_kind',
          'options.kinds has no "${d.openKind}"',
        );
      }
    } else if (m.screenDetail != null) {
      err('options.screens.detail', 'there is no detail page: remove it');
    }
    // the navigator
    final methods = {for (final o in spec.navigator!.outbound) o.name: o};
    void method(String name, String path) {
      if (!methods.containsKey(name)) {
        err(path, 'the navigator has no method "$name"');
      }
    }

    if (d != null) method(d.openCall, 'options.detail.open_call');
    for (final (i, s) in m.sections.indexed) {
      if (s.isSession) {
        method(s.openCall, 'options.sections[$i].open_call');
        method('requestSignIn', 'options.sections[$i] (requestSignIn)');
        if (!m.kinds.contains(s.openKind)) {
          err(
            'options.sections[$i].open_kind',
            'options.kinds has no "${s.openKind}"',
          );
        }
      }
    }
    final argTypes = {
      for (final o in spec.navigator!.outbound) ...o.args,
    };
    final idNames = {for (final i in m.ids) i.name};
    for (final a in argTypes) {
      if (RegExp(r'^[A-Z][A-Za-z]*Id$').hasMatch(a) && !idNames.contains(a)) {
        err('options.ids', 'the navigator takes "$a", which options.ids lacks');
      }
    }
    for (final i in m.ids) {
      if (!argTypes.contains(i.name) && m.detail?.id != i.name) {
        err(
          'options.ids',
          'options.ids has "${i.name}", which no navigator method and no '
              'detail page takes',
        );
      }
    }
    for (final b in m.barrel) {
      if (!idNames.contains(b)) {
        err(
          'options.barrel',
          'the barrel exports "$b", which options.ids lacks',
        );
      }
    }
    // kinds, ids, params, screens and tests: the roles the emitters read
    if (m.kinds.toSet().length != m.kinds.length) {
      err('options.kinds', 'options.kinds lists a kind twice');
    }
    for (final k in m.kinds) {
      if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(k)) {
        err('options.kinds', '"$k" is not a lower camel case name');
      }
    }
    if (m.kinds.isEmpty) {
      err('options.kinds', 'a dashboard needs at least one item kind');
    }
    for (final (i, id) in m.ids.indexed) {
      if (id.type != 'String' && id.type != 'int') {
        err(
          'options.ids[$i].type',
          'an id is a String or an int, not "${id.type}"',
        );
      }
    }
    if (m.idOf(m.ids.firstOrNull?.name ?? '') != null &&
        m.ids.map((i) => i.name).toSet().length != m.ids.length) {
      err('options.ids', 'options.ids lists an id twice');
    }
    for (final k in m.params.keys) {
      if (!methods.containsKey(k)) {
        err('options.params.$k', 'the navigator has no method "$k"');
      }
    }
    const testKeys = ['money', 'tag_barrel', 'tag_money', 'min_pure', 'page'];
    for (final k in m.tests.keys) {
      if (!testKeys.contains(k)) {
        err(
          'options.tests.$k',
          'unknown key "$k" (one of ${testKeys.join(', ')})',
        );
      }
    }
    if (m.tests['money'] != null &&
        m.tests['money'] != 'true' &&
        m.tests['money'] != 'false') {
      err('options.tests.money', '"money" must be "true" or "false"');
    }
    if (m.detail != null && m.screenDetail == m.screenHome) {
      err(
        'options.screens',
        'the home and the detail page need different names',
      );
    }
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(m.screenHome)) {
      err('options.screens.home', '"${m.screenHome}" is not a snake case name');
    }
    // l10n: every string the managed code reads
    final strings = {
      for (final s in spec.l10n?.strings ?? const <L10nStringSpec>[]) s.key: s,
    };
    final locales = spec.l10n?.locales ?? const [];
    for (final k in m.requiredStrings) {
      if (!strings.containsKey(k)) {
        err('l10n.strings', 'a dashboard needs the string "$k"');
      }
    }
    if (locales.isNotEmpty && locales.first == 'en_XA') {
      err(
        'l10n.locales',
        'the template locale (the first) cannot be the pseudo-locale en_XA',
      );
    }
    for (final s in strings.values) {
      for (final l in locales) {
        if (l != 'en_XA' && !s.text.containsKey(l)) {
          err('${s.path}.text', '"${s.key}" has no "$l" text');
        }
      }
      for (final l in s.text.keys) {
        if (!locales.contains(l)) {
          err(
            '${s.path}.text',
            '"${s.key}" has "$l" text, but "$l" is not in l10n.locales',
          );
        }
      }
    }
    // the first-party packages the owned files may not need are the spec's
    // business; the managed code's own are checked above.
    return out;
  }

  /// The l10n keys the managed code reads.
  List<String> get requiredStrings => [key('Title')];
}
