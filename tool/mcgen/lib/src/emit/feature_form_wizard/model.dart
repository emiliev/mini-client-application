// The form/wizard (FW) archetype's model (plan 01 section 3.3, P2-06; ADR-0017).
//
// A feature that collects values over one or more steps (`mc_forms`'
// `FormController` or `WizardController`), sends them in one write and ends
// with a flow result: `library_reading_list_editor` (a three-step wizard,
// result: the saved list's id) and `auth_signin` (one form page, result: a
// `SignInResult`).
//
// The core spec carries what every archetype shares (navigator, l10n
// strings, BDD). `options` carries the FW wiring, validated here:
//
//  - what the templates render (the barrel, the DI initializer, the
//    navigator, the flow state, the flow, the root-import list, the
//    architecture test, the package files and the `.feature` files) is read
//    from the keys below;
//  - the rest of a module (its domain, the bloc, the form's rules, the step
//    pages, the test env and most steps) is the module's own (`owned:`). A
//    new module gets working first writes of them from `options.skeleton`
//    (a wizard of text fields that posts one request).

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/options_reader.dart';
import 'package:yaml/yaml.dart';

/// A constructor argument of the flow or a field of the flow state.
class FwArg {
  const FwArg({
    required this.name,
    required this.type,
    this.defaultValue,
    this.doc,
  });

  final String name;

  /// A Dart type, `?` when optional (`ReadingListId?`, `List<DemoAccount>`).
  final String type;

  /// A Dart expression: the constructor default, or `@Default(...)`.
  final String? defaultValue;
  final String? doc;

  bool get isRequired => !type.endsWith('?') && defaultValue == null;
}

/// One page of the flow.
class FwPage {
  const FwPage({
    required this.name,
    required this.widget,
    required this.isConst,
    this.when,
  });

  /// The `McFlowPage` name (the screen name).
  final String name;

  /// The child widget, as a Dart expression (`SignInPage(reason: ...)`).
  final String widget;

  /// The `McFlowPage` itself is `const`.
  final bool isConst;

  /// `state.step >= 1`: the page is open only then.
  final String? when;
}

/// One text field of a skeleton's step.
class FwSkelField {
  const FwSkelField({
    required this.name,
    required this.label,
    required this.required,
    required this.max,
    required this.trim,
    required this.bodyKey,
  });

  /// The form field's name (`name`), also the key of its strings.
  final String name;

  /// The English label (the l10n string `<camel><Field>Label`).
  final String label;
  final bool required;

  /// The maximum length, or null.
  final int? max;
  final bool trim;

  /// The key of the field's value in the request body.
  final String bodyKey;

  String get pascal => pascalCase(name);
}

/// One step of a skeleton wizard; a step with no fields is the review.
class FwSkelStep {
  const FwSkelStep(this.id, this.fields);

  final String id;
  final List<FwSkelField> fields;

  bool get isReview => fields.isEmpty;
}

/// Thrown by [FwModel.parse] for an option a template needs and lacks;
/// lint reports it with the spec's path.
class FwError implements Exception {
  FwError(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

class FwModel {
  FwModel._(this.spec);

  final ModuleSpec spec;

  late final String pascal;
  late final String stem;
  late final String l10nFile;
  late final Map<String, String> types;
  late final List<String> barrel;
  late final List<String> rootImports;
  late final String? flowKey;
  late final List<FwArg> flowArgs;
  late final String resultType;
  late final String resultCast;
  late final String flowStateExpr;
  late final List<FwPage> pages;
  late final List<FwArg> stateFields;
  late final String archTag;
  late final int archPureOver;
  late final bool arbBlock;
  late final Map<String, String> prose;
  late final FwSkeleton? skeleton;

  // --- names ----------------------------------------------------------------
  String get module => spec.module;
  String get camel => camelCase(pascal);
  String get navigator => spec.navigator!.name;
  String get flow => '${pascal}Flow';
  String get flowState => '${pascal}FlowState';
  String get diInitializer => '${pascal}DIInitializer';
  String get rootImportsName => '${camel}RootImports';
  String get l10nClass => '${pascal}L10n';
  String get bloc => '${pascal}Bloc';
  String get event => '${pascal}Event';
  String get state => '${pascal}State';

  /// The `package:` URI of a type of [types], or of a path under `lib/src/`.
  String uriOf(String pathOrUri) =>
      pathOrUri.contains(':') ? pathOrUri : 'package:$module/src/$pathOrUri';

  /// The `package:` URI of the library that declares [name].
  String typeUri(String name) =>
      uriOf(types[name] ?? (throw FwError('options.types', 'no type "$name"')));

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

  /// The string [key] in the template locale.
  String en(String key) {
    final s = spec.l10n!.strings.firstWhere((s) => s.key == key);
    return s.text[spec.l10n!.locales.first]!;
  }

  // --- parsing --------------------------------------------------------------

  static FwModel parse(ModuleSpec spec) {
    final m = FwModel._(spec);
    final r = OptionsReader(spec.optionsNode, 'options')
      ..only(const [
        'pascal',
        'stem',
        'l10n_file',
        'types',
        'barrel',
        'root_imports',
        'flow',
        'flow_state',
        'architecture',
        'arb',
        'prose',
        'skeleton',
      ]);
    m.pascal = r.str('pascal');
    m.stem = r.str('stem', spec.module);
    m.l10nFile = r.str('l10n_file', '${m.stem}_l10n');
    m.types = r.strMap('types');
    m.barrel = r.strList('barrel');
    m.rootImports = r.strList('root_imports');
    final f = r.child('flow')
      ..only(const ['key', 'args', 'result', 'state', 'pages']);
    m.flowKey = f.optStr('key');
    m.flowArgs = f.items('args', _arg);
    final res = f.child('result')..only(const ['type', 'cast']);
    m.resultType = res.str('type');
    m.resultCast = res.str('cast');
    m.flowStateExpr = f.str('state');
    m.pages = f.items('pages', (x) {
      x.only(const ['name', 'widget', 'const', 'when']);
      return FwPage(
        name: x.str('name'),
        widget: x.str('widget'),
        isConst: x.boolean('const'),
        when: x.optStr('when'),
      );
    });
    m.stateFields = r.child('flow_state').items('fields', _arg);
    final a = r.child('architecture')..only(const ['tag', 'pure_files_over']);
    m.archTag = a.str('tag');
    m.archPureOver = a.integer('pure_files_over');
    m.arbBlock = switch (r.optStr('arb')) {
      null || 'inline' => false,
      'block_placeholders' => true,
      final other => r.fail(
        'arb',
        '"arb" must be inline or block_placeholders, not "$other"',
      ),
    };
    m.prose = r.strMap('prose');
    final sk = r.child('skeleton');
    m.skeleton = sk.isPresent ? FwSkeleton.parse(sk) : null;
    return m;
  }

  static FwArg _arg(OptionsReader x) {
    x.only(const ['name', 'type', 'default', 'doc']);
    return FwArg(
      name: x.str('name'),
      type: x.str('type'),
      defaultValue: x.optStr('default'),
      doc: x.optStr('doc'),
    );
  }

  /// Archetype lint: the options parse, and every name the templates use is
  /// declared. Lint covers every role an emitter reads (F-0069, F-0072,
  /// F-0073), so a spec that lints clean generates code that compiles.
  static List<Diagnostic> lint(ModuleSpec spec) {
    final out = <Diagnostic>[];
    void err(YamlNode? node, String path, String message) => out.add(
      Diagnostic.at(
        node ?? spec.optionsNode ?? spec.node,
        code: 'form_wizard',
        message: message,
        file: spec.file,
        yamlPath: path,
      ),
    );
    if (spec.navigator == null) {
      err(spec.node, 'navigator', 'form_wizard needs a navigator');
    }
    if (spec.l10n == null) {
      err(spec.node, 'l10n', 'form_wizard needs l10n strings');
    }
    if (spec.bdd.isEmpty) {
      err(spec.node, 'bdd', 'form_wizard needs at least one BDD feature');
    }
    if (spec.description == null) {
      err(spec.node, 'description', 'form_wizard needs a description');
    }
    final FwModel m;
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
    final node = spec.optionsNode;
    if (m.pages.isEmpty) {
      err(node, 'options.flow.pages', 'a flow needs at least one page');
    }
    final names = <String>{};
    for (final (i, p) in m.pages.indexed) {
      if (!names.add(p.name)) {
        err(node, 'options.flow.pages[$i].name', 'page "${p.name}" twice');
      }
      if (i == 0 && p.when != null) {
        err(
          node,
          'options.flow.pages[0].when',
          'the first page is the flow root and has no condition',
        );
      }
    }
    // Every type a template writes must be declared, with where it lives.
    void declared(String type, String path) {
      for (final id in _identifiers(type)) {
        if (!m.types.containsKey(id) && !_known.contains(id)) {
          err(
            node,
            path,
            'type "$id" is not in options.types (give its file under lib/src/ '
            'or its package: URI)',
          );
        }
      }
    }

    for (final (i, a) in m.flowArgs.indexed) {
      declared(a.type, 'options.flow.args[$i].type');
    }
    for (final (i, a) in m.stateFields.indexed) {
      declared(a.type, 'options.flow_state.fields[$i].type');
    }
    declared(m.resultType, 'options.flow.result.type');
    for (final (i, p) in m.pages.indexed) {
      declared(p.widget.split('(').first, 'options.flow.pages[$i].widget');
    }
    for (final id in m.barrel) {
      if (!m.types.containsKey(id)) {
        err(node, 'options.barrel', 'barrel type "$id" is not in options.types');
      }
    }
    for (final id in m.rootImports) {
      if (!m.types.containsKey(id)) {
        err(
          node,
          'options.root_imports',
          'root import "$id" is not in options.types',
        );
      }
    }
    for (final e in m.types.entries) {
      if (e.value.contains(':') && !e.value.startsWith('package:')) {
        err(node, 'options.types.${e.key}', 'a URI must start with package:');
      } else if (e.value.endsWith('/') || !e.value.endsWith('.dart')) {
        err(node, 'options.types.${e.key}', 'must be a .dart file');
      }
    }
    // The flow state's fields are what the flow's `state:` expression sets,
    // and the flow's arguments are what it reads.
    final argNames = {for (final a in m.flowArgs) a.name};
    for (final f in m.stateFields) {
      if (!RegExp('\\b${f.name}\\s*:').hasMatch(m.flowStateExpr)) {
        if (f.isRequired || f.defaultValue == null) continue;
      }
    }
    for (final a in argNames) {
      if (!RegExp('\\b$a\\b').hasMatch(m.flowStateExpr) &&
          (m.flowKey == null || !m.flowKey!.contains(a))) {
        err(
          node,
          'options.flow.args',
          'flow argument "$a" is used by neither options.flow.state nor options.flow.key',
        );
      }
    }
    if (!m.flowStateExpr.startsWith(m.flowState)) {
      err(
        node,
        'options.flow.state',
        'must construct ${m.flowState}, not "${m.flowStateExpr}"',
      );
    }
    final strings = {
      for (final s in spec.l10n?.strings ?? const <L10nStringSpec>[]) s.key: s,
    };
    final locales = spec.l10n?.locales ?? const [];
    if (locales.isNotEmpty && locales.first == 'en_XA') {
      err(
        spec.node,
        'l10n.locales',
        'the template locale (the first) cannot be the pseudo-locale en_XA',
      );
    }
    for (final s in strings.values) {
      for (final l in locales) {
        if (l != 'en_XA' && !s.text.containsKey(l)) {
          err(spec.node, '${s.path}.text', '"${s.key}" has no "$l" text');
        }
      }
      for (final l in s.text.keys) {
        if (!locales.contains(l)) {
          err(
            spec.node,
            '${s.path}.text',
            '"${s.key}" has "$l" text, but "$l" is not in l10n.locales',
          );
        }
      }
    }
    final sk = m.skeleton;
    if (sk != null) out.addAll(sk.lint(m, err, strings.keys.toSet()));
    return out;
  }

  /// Names a type may use without `options.types`: `dart:core` names the
  /// templates never import.
  static const _known = {
    'String',
    'int',
    'bool',
    'double',
    'num',
    'List',
    'Map',
    'Set',
    'Object',
    'dynamic',
    'void',
    'Future',
    'DateTime',
    'Duration',
    'const',
  };

  static Iterable<String> _identifiers(String type) => RegExp(
    r'[A-Z][A-Za-z0-9_]*|\b(?:int|bool|double|num)\b',
  ).allMatches(type).map((m) => m[0]!);
}

/// What a new module gets as first writes (`options.skeleton`): a wizard of
/// text fields (one step is a form) that sends one request with the
/// session's epoch pinned, and ends with the new item's id. An exemplar sets
/// none of it.
class FwSkeleton {
  FwSkeleton._();

  late final String noun;
  late final String resultName;
  late final String resultFile;
  late final String? resultDoc;
  late final String path;
  late final String idKey;
  late final Map<String, String> extra;
  late final List<FwSkelStep> steps;
  late final String signedIn;
  late final List<String> fixtures;

  static FwSkeleton parse(OptionsReader r) {
    r.only(const [
      'noun',
      'result',
      'submit',
      'steps',
      'signed_in',
      'fixtures',
    ]);
    final s = FwSkeleton._();
    s.noun = r.str('noun');
    final res = r.child('result')..only(const ['name', 'file', 'doc']);
    s.resultName = res.str('name');
    s.resultFile = res.str('file');
    s.resultDoc = res.optStr('doc');
    final sub = r.child('submit')..only(const ['path', 'id_key', 'extra']);
    s.path = sub.str('path');
    s.idKey = sub.str('id_key', 'id');
    s.extra = sub.strMap('extra');
    s.signedIn = r.str('signed_in');
    s.fixtures = r.strList('fixtures');
    s.steps = r.items('steps', (x) {
      x.only(const ['id', 'fields']);
      return FwSkelStep(
        x.str('id'),
        x.items('fields', (f) {
          f.only(const ['name', 'label', 'required', 'max', 'trim', 'body']);
          final name = f.str('name');
          return FwSkelField(
            name: name,
            label: f.str('label'),
            required: f.boolean('required'),
            max: f.optInt('max'),
            trim: f.boolean('trim'),
            bodyKey: f.str('body', name),
          );
        }),
      );
    });
    return s;
  }

  List<FwSkelField> get fields => [for (final s in steps) ...s.fields];

  /// The l10n keys a skeleton's pages and form use.
  List<String> requiredKeys(FwModel m) => [
    for (final s in const [
      'Title',
      'Step',
      'Back',
      'Next',
      'Create',
      'BlockedHint',
      'SessionEndedTitle',
      'SessionEndedMessage',
      'Saving',
    ])
      '${m.camel}$s',
    for (final step in steps)
      if (step.isReview) '${m.camel}${pascalCase(step.id)}Title',
    for (final f in fields) ...[
      '${m.camel}${f.pascal}Label',
      '${m.camel}${f.pascal}Refused',
      if (f.required) '${m.camel}${f.pascal}Required',
      if (f.max != null) '${m.camel}${f.pascal}TooLong',
    ],
  ];

  List<Diagnostic> lint(
    FwModel m,
    void Function(YamlNode?, String, String) err,
    Set<String> strings,
  ) {
    final out = <Diagnostic>[];
    final node = m.spec.optionsNode;
    if (steps.isEmpty) {
      err(node, 'options.skeleton.steps', 'a skeleton needs at least one step');
    }
    if (steps.isNotEmpty && steps.first.isReview) {
      err(
        node,
        'options.skeleton.steps[0]',
        'the first step needs fields (only the last may be the review)',
      );
    }
    for (final (i, s) in steps.indexed) {
      if (s.isReview && i != steps.length - 1) {
        err(
          node,
          'options.skeleton.steps[$i]',
          'a step without fields is the review and must be the last',
        );
      }
    }
    if (steps.length > 1 && !steps.last.isReview) {
      err(
        node,
        'options.skeleton.steps',
        'a wizard of several steps ends with a review step (no fields)',
      );
    }
    final seen = <String>{};
    for (final f in fields) {
      if (!seen.add(f.name)) {
        err(node, 'options.skeleton.steps', 'field "${f.name}" twice');
      }
    }
    final ids = <String>{};
    for (final s in steps) {
      if (!ids.add(s.id)) {
        err(node, 'options.skeleton.steps', 'step "${s.id}" twice');
      }
    }
    if (!m.types.containsKey(resultName)) {
      err(
        node,
        'options.types',
        'the skeleton result "$resultName" is not in options.types',
      );
    }
    for (final k in requiredKeys(m)) {
      if (!strings.contains(k)) {
        err(m.spec.node, 'l10n.strings', 'form_wizard needs the string "$k"');
      }
    }
    for (final r in const ['Dio', 'EventBus']) {
      if (r == 'EventBus') continue;
      if (!m.rootImports.contains(r)) {
        err(
          node,
          'options.root_imports',
          'a skeleton sends its request through Dio: root_imports needs "$r"',
        );
      }
    }
    for (final r in const ['SessionReader', 'Monitoring']) {
      if (!m.rootImports.contains(r)) {
        err(
          node,
          'options.root_imports',
          'a skeleton reads the session and reports to monitoring: '
          'root_imports needs "$r"',
        );
      }
    }
    if (m.flowArgs.isNotEmpty) {
      err(
        node,
        'options.flow.args',
        'a skeleton flow starts from nothing: no flow arguments',
      );
    }
    if (m.resultType != '$resultName?') {
      err(
        node,
        'options.flow.result.type',
        'a skeleton flow ends with "$resultName?" (null: it ended unsaved)',
      );
    }
    final stepField = m.stateFields.map((f) => f.name);
    if (!stepField.contains('step')) {
      err(
        node,
        'options.flow_state.fields',
        'a skeleton flow state has an int field "step" (the deepest open step)',
      );
    }
    if (m.pages.length != steps.length) {
      err(
        node,
        'options.flow.pages',
        'a skeleton has one flow page per step '
        '(${m.pages.length} pages, ${steps.length} steps)',
      );
    }
    final pageClass = '${m.pascal}StepPage';
    for (final (i, p) in m.pages.indexed) {
      final want = 'const $pageClass(step: $i)';
      if (p.widget != want) {
        err(
          node,
          'options.flow.pages[$i].widget',
          'a skeleton page is "$want", not "${p.widget}"',
        );
      }
    }
    if (!m.types.containsKey(pageClass)) {
      err(node, 'options.types', 'a skeleton needs the type "$pageClass"');
    }
    if (m.spec.navigator!.outbound.isNotEmpty) {
      err(
        m.spec.node,
        'navigator.outbound',
        'a skeleton navigator has no methods (the flow ends with its result)',
      );
    }
    return out;
  }
}
