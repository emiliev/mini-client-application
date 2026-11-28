// The section-detail tests (ADR-0015: BDD plus contract tests, no goldens):
// the step files the features use, the favourites probe and the architecture
// test (managed), and the test env and the flow-scope test (owned after
// their first write: they hold fixture lookups, which are top-level
// declarations, and a keep region cannot).
//
// Templates here are raw text with `<<name>>` placeholders and `«Symbol»`
// references (see `templateRefs`), so Dart's own `$` needs no escaping.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';
import 'package:mcgen/src/emit/feature_section_detail/step_templates.dart';

/// The names the owned env declares, which managed steps reference.
List<String> envNames(ScModel m) => [
  m.envNavigator,
  m.envContainer,
  m.envHost,
  m.envUnderTest,
  m.envPageKey,
  m.envScrollable,
  m.envScrollUntil,
  m.envTap,
  m.tests.factsKey,
  m.navigatorMock,
  'pendingSignIns',
  'announcedChanges',
  'fixtureUser',
  'plainSpaces',
  'favouriteErrorKey',
  m.detailsBodyKey,
];

Map<String, String> _vars(ScModel m) => {
  'module': m.module,
  'item': m.itemWords,
  'itemCamel': m.itemCamel,
  'idPrim': m.idPrim,
  'favouriteUrl':
      '/${m.favouritePath.replaceFirst('{id}', '\$${m.itemCamel}')}',
  'Item': m.itemPascal,
  'items': m.items,
  'scroll': m.scroll.replaceAll('_', ' '),
  'page': m.scroll == m.item
      ? 'details page'
      : '${m.scroll.replaceAll('_', ' ')} page',
  'Prefix': m.prefix,
  'prefixCamel': m.prefixCamel,
  'Flow': m.flow,
  'Navigator': m.navigator,
  'Mock': m.navigatorMock,
  'IdType': m.itemIdType,
  'idArg': m.idArg,
  'envNavigator': m.envNavigator,
  'envContainer': m.envContainer,
  'envHost': m.envHost,
  'envUnderTest': m.envUnderTest,
  'envPageKey': m.envPageKey,
  'envScrollable': m.envScrollable,
  'envScrollUntil': m.envScrollUntil,
  'envTap': m.envTap,
  'factsKey': m.tests.factsKey,
  'detailsBodyKey': m.detailsBodyKey,
  'email': m.tests.userEmail,
  'favouriteKind': m.favouriteKind,
  'fixtureSetLists': m.tests.env['fixture_set_lists'] ?? '',
};

/// The step file name -> the template key.
Map<String, String> _stepNames(ScModel m) => {
  'i_open_${snakeCase(m.item)}': 'open',
  'i_open_${snakeCase(m.item)}_on_two_pages': 'open_two',
  'i_scroll_the_${snakeCase(m.scroll)}_to_the_end': 'scroll_end',
  'i_scroll_the_${snakeCase(m.scroll)}_until_i_see': 'scroll_until',
  'i_tap_on_page': 'tap_on_page',
  'page_shows': 'page_shows',
  'another_page_announces_a_change_to': 'another_page',
  'the_app_announced_change_to': 'announced',
  'signing_in_succeeds_as': 'sign_in_ok',
  'signing_in_is_cancelled': 'sign_in_cancel',
  'signs_in_elsewhere': 'signs_in_elsewhere',
  'the_app_was_asked_to_sign_in_time': 'asked_sign_in',
  'the_session_ends_elsewhere': 'session_ends',
  'the_user_is_signed_out': 'signed_out',
  'the_favourite_toggle_shows_enabled_and_on': 'toggle_on',
  '${snakeCase(m.item)}_is_a_favourite_of': 'is_fav',
  '${snakeCase(m.item)}_is_not_a_favourite_of': 'not_fav',
  'has_${snakeCase(m.item)}_among_their_favourites': 'has_fav',
  'the_fact_reads': m.tests.plainFacts ? 'fact_reads' : 'fact_reads_exact',
};

void emitTests(EmitContext ctx, ScModel m) {
  final barrel = 'package:${m.module}/${m.module}.dart';
  final v = _vars(m);
  final names = _stepNames(m);
  final usage = <String, String>{};
  for (final line in allSteps(m.spec.bdd)) {
    usage.putIfAbsent(stepFileName(line), () => stepText(line));
  }
  // The open steps: `the app was asked to open <label> {..}` (and `{n} times`)
  // for each hand-over the spec gives a lookup for.
  final openSteps = <String, (ScOpen, bool)>{
    for (final o in m.opens)
      if (o.lookup != null) ...{
        'the_app_was_asked_to_open_${snakeCase(o.label)}': (o, false),
        'the_app_was_asked_to_open_${snakeCase(o.label)}_times': (o, true),
      },
  };
  for (final MapEntry(key: name, value: text) in usage.entries) {
    if (sharedSteps.contains(name)) continue;
    final fn = stepFunctionName(text);
    final path = 'test/feature/step/$name.dart';
    final usageLine = m.text('step.$name.usage', text);
    final open = openSteps[name];
    if (open != null) {
      ctx.library(
        _openStep(m, path, fn, usageLine, barrel, open.$1, times: open.$2),
      );
      continue;
    }
    final key = names[name];
    if (key == null) {
      ctx.library(_stub(path, fn, usageLine, text), owned: true);
      continue;
    }
    final template = stepTemplates[key]!;
    final doc = template.doc == null
        ? null
        : m.text('step.$name.doc', _plain(tpl(template.doc!, v)));
    ctx.library(
      DartLibrary(
        path,
        imports: [
          flutterTest,
          for (final u in template.imports) u == 'BARREL' ? barrel : u,
        ],
        decls: [
          RawDecl(
            Code(tpl(template.decl, {...v, 'fn': fn})),
            name: fn,
            doc: 'Usage: $usageLine${doc == null ? '' : '\n\n$doc'}',
          ),
        ],
      ),
    );
  }
  ctx.library(_probe(m, v));
  ctx.library(_env(m, v, barrel), owned: true);
  for (final n in envNames(m)) {
    ctx.symbols.define(n, 'path:${m.envFile}');
  }
  ctx.library(_flowScopeTest(m, v, barrel), owned: true);
  ctx.library(_architectureTest(m));
}

/// Doc text from a template: its `«Ref»` marks are only for code.
String _plain(String text) => text
    .replaceAll(RegExp('[\u0000-\u0002]'), '')
    .replaceAll('«', '')
    .replaceAll('»', '');

/// A step mcgen has no template for: written once, for a human to fill in.
DartLibrary _stub(String path, String fn, String usage, String text) {
  final params = [
    'WidgetTester tester',
    for (final (i, p) in stepParams(text).indexed)
      '${RegExp(r'^-?[0-9]+$').hasMatch(p) ? 'int' : 'String'} p${i + 1}',
  ];
  return DartLibrary(
    path,
    imports: [flutterTest],
    decls: [
      RawDecl(
        Code(
          'Future<void> $fn(${params.join(', ')}) async {\n'
          "  fail('step \"$fn\" is not written yet');\n"
          '}',
        ),
        name: fn,
        doc:
            'Usage: $usage\n\nWritten once by mcgen (no section_detail template); owned from now on.',
      ),
    ],
  );
}

/// `the app was asked to open <label> {name}` (or `{n} times`): the navigator
/// mock saw `<calls>` with the id of the fixture record [o.lookup] finds.
DartLibrary _openStep(
  ScModel m,
  String path,
  String fn,
  String usage,
  String barrel,
  ScOpen o, {
  required bool times,
}) {
  final p = o.lookupParam;
  final id = o.idLocal ? 'id' : '${o.id}(${o.lookup}($p).${o.idField})';
  final local = o.idLocal
      ? '  final id = ${o.id}(${o.lookup}($p).${o.idField});\n'
      : '';
  final doc = times
      ? null
      : m.text(
          'step.${snakeCase(o.label)}.open_doc',
          'The navigator contract: `${o.calls}` with the id of the ${o.label} named\n'
              '[$p], exactly once, and nothing else.',
        );
  final body = times
      ? 'final navigator = ${ref(m.envNavigator)}();\n'
            '$local  verify(${o.idLocal ? '() => navigator.${o.calls}($id)' : '\n    () => navigator.${o.calls}($id),\n  '}).called(times);\n'
      : 'final navigator = ${ref(m.envNavigator)}();\n'
            '$local  verify(() => navigator.${o.calls}($id)).called(1);\n';
  return DartLibrary(
    path,
    imports: [flutterTest, barrel, 'package:mocktail/mocktail.dart'],
    decls: [
      RawDecl(
        Code(
          'Future<void> $fn(\n'
          '  WidgetTester tester,\n'
          '  ${o.lookupParamType} $p,${times ? '\n  int times,' : ''}\n'
          ') async {\n'
          '  $body'
          '  verifyNoMoreInteractions(navigator);\n'
          '}',
        ),
        name: fn,
        doc: 'Usage: $usage${doc == null ? '' : '\n\n$doc'}',
      ),
    ],
  );
}

DartLibrary _probe(ScModel m, Map<String, String> v) {
  return DartLibrary(
    'test/feature/util/favourites_probe.dart',
    imports: [
      'package:dio/dio.dart',
      flutterTest,
      'package:mc_fixtures_identity/mc_fixtures_identity.dart',
      'package:mc_test_utils/mc_test_utils.dart',
    ],
    decls: [
      RawDecl(
        Code(
          tpl(r'''Future<Response<Object?>> favouritesProbe(
  WidgetTester tester,
  String email,
  String method,
  <<idPrim>> <<itemCamel>>,
) async {
  final user = «fixtureUser»(email);
  final dio = McTestSession.current.backend.backend.createDio();
  final response = await tester.runAsync(
    () => dio.request<Object?>(
      '<<favouriteUrl>>',
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer ${mintAccessToken(user.id, 9999)}'},
        validateStatus: (_) => true,
      ),
    ),
  );
  return response!;
}''', v),
        ),
        name: 'favouritesProbe',
        doc:
            'Talks to the backend\'s identity domain directly, as [email], with a token\n'
            'of the fixture\'s shape: a second client that reads or seeds what the\n'
            'backend holds. It bypasses the app\'s `Dio` and the harness, so it adds no\n'
            'request to what the scenario asserts on.',
      ),
    ],
  );
}

// --- the owned env ----------------------------------------------------------------

DartLibrary _env(ScModel m, Map<String, String> v, String barrel) {
  final fixtures = [
    for (final p in (m.tests.env['fixture_packages'] ?? '').split(' '))
      if (p.isNotEmpty) 'package:$p/$p.dart',
  ];
  final setups = [
    for (final s in (m.tests.env['fixture_set_lists'] ?? '').split(' '))
      if (s.isNotEmpty) '  $s.forEach(McFixtureSets.register);',
  ].join('\n');
  return DartLibrary(
    m.envFile,
    imports: [
      dartAsync,
      barrel,
      material,
      flutterTest,
      'package:mc_di/mc_di.dart',
      'package:mc_ds_media/mc_ds_media.dart',
      'package:mc_event_bus/mc_event_bus.dart',
      'package:mc_fixtures_identity/mc_fixtures_identity.dart',
      'package:mc_fixtures_media/mc_fixtures_media.dart',
      'package:mc_test_utils/mc_test_utils.dart',
      'package:mocktail/mocktail.dart',
      ...fixtures,
    ],
    decls: [
      RawDecl(
        Code(
          tpl(
            r'''class <<Mock>> extends Mock implements <<Navigator>> {}

final Expando<<<Mock>>> _navigators = Expando('<<module>> navigator');
final Expando<List<Completer<bool>>> _signIns = Expando('<<module>> sign-ins');
final Expando<List<DataChanged>> _changes = Expando('<<module>> changes');

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub;
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`), so a scenario can
/// look at the page while the feature waits for the app.
<<Mock>> <<envNavigator>>() =>
    _navigators[McTestSession.current] ??= _newNavigator();

<<Mock>> _newNavigator() {
  final navigator = <<Mock>>();
  when(navigator.requestSignIn).thenAnswer((_) {
    final answer = Completer<bool>();
    pendingSignIns().add(answer);
    return answer.future;
  });
  return navigator;
}

/// The sign-ins the feature asked for and nobody answered yet, oldest first.
List<Completer<bool>> pendingSignIns() =>
    _signIns[McTestSession.current] ??= [];

/// Every `DataChanged` published on the bus since the <<item>> opened.
List<DataChanged> announcedChanges() => _changes[McTestSession.current] ??= [];

final Expando<bool> _observed = Expando('<<module>> observers');

/// The test root, once per test: the production-shaped container (unless an
/// earlier step such as `I am signed in as` made it), plus a listener on the
/// bus. Called by `I open <<item>>`.
Future<void> <<envContainer>>() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
  if (_observed[session] ?? false) {
    return;
  }
  _observed[session] = true;
  final changes = announcedChanges();
  final subscription = diContainer<EventBus>().on<DataChanged>().listen(
    changes.add,
  );
  addTearDown(subscription.cancel);
}

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const <<detailsBodyKey>> = ValueKey<String>('<<module>>.body');
const <<factsKey>> = ValueKey<String>('<<module>>.facts');
const favouriteErrorKey = ValueKey<String>('<<module>>.favourite.error');

/// The key of page [n] in `I open <<item>> {id} on two pages` (a test host
/// key, not a feature key).
ValueKey<String> <<envPageKey>>(int n) => ValueKey<String>('test.<<item>>.page.$n');

/// The details page's own scrollable.
Finder <<envScrollable>>() => find.descendant(
  of: find.byKey(<<detailsBodyKey>>),
  matching: find.byType(Scrollable),
);

/// Drags the details page until [finder] is on screen.
Future<void> <<envScrollUntil>>(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: <<envScrollable>>().first,
  );
  await mcSettle(tester);
}

/// Scrolls [target] into view, then taps it [times] times, [between] of fake
/// time apart (zero: within one frame), then settles.
Future<void> <<envTap>>(
  WidgetTester tester,
  Finder target, {
  int times = 1,
  Duration between = Duration.zero,
}) async {
  await <<envScrollUntil>>(tester, target);
  expect(target.hitTestable(), findsOneWidget, reason: 'one tappable target');
  for (var i = 0; i < times; i++) {
    if (i > 0 && between > Duration.zero) {
      await tester.pump(between);
    }
    await tester.tap(target.hitTestable());
  }
  await mcSettle(tester);
}

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget <<envHost>>(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget <<envUnderTest>>(<<idPrim>> id) =>
    <<Flow>>(navigator: <<envNavigator>>(), <<idArg>>: <<IdType>>(id));

<<extra>>

/// Text with its non-breaking and narrow spaces as plain ones: intl puts
/// them between a German amount and its currency sign.
String plainSpaces(String text) => text.replaceAll(RegExp('[  ]'), ' ');

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
<<setups>>
  identityFixtureSets.forEach(McFixtureSets.register);
}''',
            {...v, 'setups': setups, 'extra': m.tests.env['extra'] ?? ''},
          ),
        ),
        name: 'bddSetUpAll',
      ),
    ],
  );
}

// --- the owned flow-scope test --------------------------------------------------------

DartLibrary _flowScopeTest(ScModel m, Map<String, String> v, String barrel) {
  final tag = m.tag('flow_scope');
  final sets = [
    for (final s in m.tests.fixtureSets) "      ..useFixtureSet('$s')",
  ].join('\n');
  final sample = m.tests.env['sample_id'] ?? '1';
  return DartLibrary(
    'test/flow_scope_test.dart',
    preamble: commentLines(
      'The flow as a unit of wiring, entered through the barrel only. R17: its\n'
      'hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a\n'
      'missing one fails at flow creation, naming the type (`mcgen wire` will\n'
      'generate the list, Phase D).',
    ),
    imports: [
      'package:dio/dio.dart',
      flutterTest,
      'package:mc_di/mc_di.dart',
      'package:mc_ds_navigation/mc_ds_navigation.dart',
      'package:mc_event_bus/mc_event_bus.dart',
      'package:mc_feature_flow/mc_feature_flow.dart',
      'package:mc_monitoring/mc_monitoring.dart',
      'package:mc_test_utils/mc_test_utils.dart',
    ],
    decls: [
      RawDecl(
        Code(
          tpl(
            '''void main() {
  setUpAll(«bddSetUpAll»);

  void serve() {
    McTestSession.current.backend
$sets;
  }

  mcTestWidgets("${tag}the flow's container resolves every registration", (
    tester,
  ) async {
    serve();
    await initFlow(tester, () => «<<envHost>>»(«<<envUnderTest>>»($sample)));
    await mcSettle(tester);

    final page = tester.element(find.byKey(«<<detailsBodyKey>>»));
    // Navigator, API, repository and both blocs (no factory parameters).
    await page.debugResolveAll();
    await mcSettle(tester);
  });

  mcTestWidgets('${tag}a root without a forwarded type fails naming it', (
    tester,
  ) async {
    final session = McTestSession.current;
    // A root with Dio, the bus and Monitoring, but no session, which the
    // flow forwards.
    await initializeDIContainer([
      McDIInitializer((getIt, _) {
        getIt
          ..registerSingleton<Dio>(session.backend.backend.createDio())
          ..registerSingleton<EventBus>(EventBus())
          ..registerSingleton<Monitoring>(session.monitoring);
      }),
    ]);
    await tester.pumpWidget(
      McTestApp(
        session: session,
        home: «<<envHost>>»(«<<envUnderTest>>»($sample)),
      ),
    );
    await tester.pump();

    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect('\$error', contains('RootImport<SessionReader>'));
    expect(find.byKey(«<<detailsBodyKey>>»), findsNothing);
  });

  mcTestWidgets('${tag}the details page uses McAppBar with McFlowBackButton', (
    tester,
  ) async {
    serve();
    await initFlow(tester, () => «<<envHost>>»(«<<envUnderTest>>»($sample)));
    await mcSettle(tester);

    final bar = tester.widget<McAppBar>(find.byType(McAppBar));
    expect(bar.leading, isA<McFlowBackButton>());
  });
}''',
            v,
          ),
        ),
        name: 'main',
      ),
    ],
  );
}

// --- the architecture test --------------------------------------------------------------

DartLibrary _architectureTest(ScModel m) {
  final tag = m.tag('architecture');
  final exports = [
    m.flow,
    m.navigator,
    for (final i in m.ids) i.name,
  ].map((n) => "'$n'").join(', ');
  return DartLibrary(
    'test/architecture/architecture_test.dart',
    preamble: commentLines(
      "Conformance of the package's shape (plan 01 §3.3), not a test of feature\n"
      'behaviour: R4 (the barrel) and R15 (generators read Flutter-free files).',
    ),
    imports: ['dart:io', 'package:test/test.dart'],
    decls: [
      RawDecl(
        Code(
          r'''/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => '<<dir>>/$rel';

/// One export directive, in either quote style, with an optional `show`.
final RegExp _export = RegExp(
  r<<TQ>>export\s+(['"])([^'"]+)\1\s*(show\s+([^;]+))?;<<TQ>>,
  multiLine: true,
);

/// Any export directive at all, to check [_export] understood each one.
final RegExp _anyExport = RegExp(r'^\s*export\b', multiLine: true);

/// A Flutter import or export, in either quote style.
final RegExp _flutter = RegExp(
  r<<TQ>>(import|export)\s+['"](package:flutter[a-z_]*/|dart:ui)<<TQ>>,
);

void main() {
  test('<<tag>>the barrel exports only the flow, the navigator and their '
      'argument types, each with show', () {
    final barrel = File(_path('lib/<<module>>.dart')).readAsStringSync();
    final exports = _export.allMatches(barrel).toList();

    expect(exports, isNotEmpty);
    expect(
      exports,
      hasLength(_anyExport.allMatches(barrel).length),
      reason: 'every export directive is one this check understands',
    );
    final shown = <String>{};
    for (final e in exports) {
      expect(
        e.group(3),
        isNotNull,
        reason: '${e.group(2)} exports without show',
      );
      shown.addAll(e.group(4)!.split(',').map((s) => s.trim()));
      expect(e.group(2), startsWith('package:<<module>>/src/'));
    }
    expect(shown, {<<exports>>});
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('<<tag>>every file a generator reads imports no Flutter (R15)', () {
    final list = File(_path('test/architecture/pure_srcs.txt'));
    final files = list
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    expect(files, hasLength(greaterThan(<<min>>)));
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

  test('<<tag>>the checks read both quote styles', () {
    expect(_flutter.hasMatch('import "package:flutter/widgets.dart";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter/widgets.dart';"), isTrue);
    expect(_flutter.hasMatch('export "dart:ui";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter_bloc/x.dart';"), isTrue);
    expect(_flutter.hasMatch("import 'package:freezed/x.dart';"), isFalse);

    final e = _export.firstMatch('export "package:x/src/a.dart" show A, B;')!;
    expect(e.group(2), 'package:x/src/a.dart');
    expect(e.group(4), 'A, B');
    expect(_export.hasMatch('export "package:x/a.dart\';'), isFalse);
  });
}'''
              .replaceAll('<<TQ>>', "'''")
              .replaceAll('<<dir>>', m.spec.moduleDir)
              .replaceAll('<<tag>>', tag)
              .replaceAll('<<module>>', m.module)
              .replaceAll('<<exports>>', exports)
              .replaceAll('<<min>>', '${m.tests.minPure}'),
        ),
        name: 'main',
      ),
    ],
  );
}
