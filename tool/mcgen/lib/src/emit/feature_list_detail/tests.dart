// The list-detail tests (ADR-0015: BDD plus contract tests, no goldens):
// the step files the features use, the test environment (owned after its
// first write), the flow-scope test, the architecture test and the contract
// test (owned after its first write).
//
// Templates here are raw text with `<<name>>` placeholders and `«Symbol»`
// references (see `templateRefs`), so Dart's own `$` needs no escaping.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

/// [raw] with `<<name>>` replaced from [vars] and `«Symbol»` references.
String tpl(String raw, Map<String, String> vars) {
  final text = raw.replaceAllMapped(RegExp(r'<<(\w+)>>'), (m) {
    final v = vars[m[1]];
    if (v == null) throw StateError('template variable <<${m[1]}>> unset');
    return v;
  });
  return templateRefs(text);
}

/// One step file's template: its doc after the usage line, its parameters,
/// its body and the libraries it imports by URI.
class _Step {
  const _Step(this.doc, this.params, this.body, {this.imports = const []});

  final String doc;
  final String params;
  final String body;
  final List<String> imports;
}

void emitTests(EmitContext ctx, LdModel m) {
  final env = 'test/feature/util/${m.module}_env.dart';
  final barrel = 'package:${m.module}/${m.module}.dart';
  final v = _vars(m);
  final templates = _stepTemplates(m, v, barrel);
  final usage = <String, String>{};
  for (final line in allSteps(m.spec.bdd)) {
    usage.putIfAbsent(stepFileName(line), () => stepText(line));
  }
  for (final MapEntry(key: name, value: text) in usage.entries) {
    if (sharedSteps.contains(name)) continue;
    final fn = stepFunctionName(text);
    final t = templates[name];
    final path = 'test/feature/step/$name.dart';
    final usageLine = m.text('step.$name.usage', text);
    if (t == null) {
      ctx.library(_stub(path, fn, usageLine, text), owned: true);
      continue;
    }
    ctx.library(
      DartLibrary(
        path,
        imports: [flutterTest, ...t.imports],
        decls: [
          RawDecl(
            Code(
              'Future<void> $fn(${t.params}) async${t.body.startsWith('=>') ? ' ' : ' '}${t.body}',
            ),
            name: fn,
            doc: 'Usage: $usageLine\n\n${m.text('step.$name.doc', t.doc)}',
          ),
        ],
      ),
    );
  }
  ctx.library(_env(m, v, barrel), owned: true);
  for (final n in _envNames(m, v)) {
    ctx.symbols.define(n, 'path:$env');
  }
  ctx.library(_flowScopeTest(m, v, barrel));
  ctx.library(_architectureTest(m));
  ctx.library(_contractTest(m, v), owned: true);
}

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
            'Usage: $usage\n\nWritten once by mcgen (no list_detail template); owned from now on.',
      ),
    ],
  );
}

Map<String, String> _vars(LdModel m) => {
  'module': m.module,
  'Module': m.pascal,
  'moduleDir': m.spec.moduleDir,
  'item': m.item,
  'items': m.items,
  'Item': m.itemPascal,
  'itemCamel': m.itemCamel,
  'itemsCamel': m.itemsCamel,
  'list': m.listNoun,
  'flow': m.flow,
  'navigator': m.navigator,
  'Id': m.listEntityId,
  'records': m.tests.records,
  'recordTitle': m.tests.record.title,
  'recordImage': m.tests.record.image,
  'recordId': m.tests.record.id,
  'lookup': '${m.itemCamel}${participle(m.tests.record.title)}',
  'title': m.titleField,
  'gridKey': m.gridKey,
  'titleKey': m.previewTitleKey,
  'artKey': m.previewArtKey,
  'host': '${m.itemsCamel}TestHost',
  'underTest': '${m.camel}FlowUnderTest',
  'nav': '${m.itemsCamel}Navigator',
  'flowState': '${m.itemsCamel}FlowState',
  'scrollable': '${m.itemsCamel}Scrollable',
  'position': '${m.itemsCamel}ScrollPosition',
  'shown': '${m.itemsCamel}Shown',
  'mockNav': 'Mock${m.navigator}',
  'listTitle': _en(m, m.key('Title')),
};

String _en(LdModel m, String key) =>
    m.spec.l10n!.strings.firstWhere((s) => s.key == key).text['en']!;

Map<String, _Step> _stepTemplates(
  LdModel m,
  Map<String, String> v,
  String barrel,
) {
  final list = m.listNoun.replaceAll(' ', '_');
  final item = m.item.replaceAll(' ', '_');
  final items = m.items.replaceAll(' ', '_');
  String t(String raw) => tpl(raw, v);
  final out = <String, _Step>{
    'i_open_the_$list': _Step(
      t(
        'Enters the feature the way the app does: through its flow (barrel only),\n'
        'with the navigator passed in the constructor [tide-nav §3.1].',
      ),
      'WidgetTester tester',
      t(r'''{
  await «initFlow»(
    tester,
    () => «<<host>>»(«<<underTest>>»()),
  );
  await «mcSettle»(tester);
}'''),
    ),
    'i_scroll_the_${list}_to_the_end': _Step(
      t(
        'Real drags until the grid sits at its end with nothing loading: the last\n'
        'page arrived, or a later page failed (its footer offers Retry).',
      ),
      'WidgetTester tester',
      t(r'''{
  final loadingMore = find.descendant(
    of: find.byKey(«<<gridKey>>»),
    matching: find.byType(«McLoading»),
  );
  for (var drags = 0; drags < 100; drags++) {
    final position = «<<position>>»(tester);
    if (position.pixels >= position.maxScrollExtent &&
        loadingMore.evaluate().isEmpty) {
      await «mcSettle»(tester);
      return;
    }
    await tester.drag(«<<scrollable>>»(), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the <<list>> did not reach its end after 100 drags');
}'''),
    ),
    'i_scroll_the_${list}_until_i_see': _Step(
      t(
        'Drags the grid until [name] is on screen, then remembers the scroll\n'
        'position for `the <<list>> keeps its scroll position`.',
      ),
      'WidgetTester tester,\n  String name,',
      t(r'''{
  await tester.scrollUntilVisible(
    find.text(name),
    200,
    scrollable: «<<scrollable>>»(),
  );
  await «mcSettle»(tester);
  «rememberScrollOffset»(«<<position>>»(tester).pixels);
}'''),
    ),
    'i_scroll_the_${list}_until_the_next_page_loads': _Step(
      t(
        'Real drags, 200 px at a time, until the grid holds more <<items>> than\n'
        'before (the load-more threshold fired and the page arrived).',
      ),
      'WidgetTester tester,',
      t(r'''{
  final before = «<<shown>>»(tester);
  for (var drags = 0; drags < 100; drags++) {
    await tester.drag(«<<scrollable>>»(), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 100));
    if («<<shown>>»(tester) > before) {
      await «mcSettle»(tester);
      return;
    }
  }
  fail('the grid still holds $before <<items>> after 100 drags');
}'''),
    ),
    'the_${list}_shows_$items': _Step(
      t('The grid\'s item count: every loaded <<item>>, on screen or not.'),
      'WidgetTester tester,\n  int count,',
      t(r'''=> expect(«<<shown>>»(tester), count);'''),
    ),
    'the_${list}_keeps_its_scroll_position': _Step(
      t(
        'The grid is where `I scroll the <<list>> until I see` left it, and\n'
        'that was not the top.',
      ),
      'WidgetTester tester,',
      t(r'''{
  final remembered = «rememberedScrollOffset»();
  expect(remembered, isNotNull, reason: 'no earlier step scrolled the list');
  expect(remembered, greaterThan(0), reason: 'the list was scrolled down');
  expect(«<<position>>»(tester).pixels, remembered);
}'''),
    ),
    'i_dont_see_the_${item}_preview': _Step(
      t('The preview page left the flow, and the flow state selects nothing.'),
      'WidgetTester tester',
      t(r'''{
  expect(
    find.byKey(«<<titleKey>>», skipOffstage: false),
    findsNothing,
  );
  expect(«<<flowState>>»(tester).preview, isNull);
}'''),
    ),
    'i_see_the_${item}_preview_for': _Step(
      t(
        'The preview shows [name] and its bundled art, and it is flow state, not a\n'
        'pushed route:\n'
        '- the flow state selects [name] (read through the flow\'s controller);\n'
        '- the route is a `Page` the flow generated (a pushed route has plain\n'
        '  `RouteSettings`), named `preview`, with the <<item>>\'s id as argument,\n'
        '  on the flow\'s navigator rather than the app\'s;\n'
        '- the page is keyed by that id, so another selection gets a new page.',
      ),
      'WidgetTester tester,\n  String name,',
      '${t(r'''{
  final record = «<<lookup>>»(name);
  final id = <<Id>>(record.<<recordId>>);

  final selected = «<<flowState>>»(tester).preview;
  expect(selected?.id, id, reason: 'the flow state selects $name');
  expect(selected?.<<title>>, name);

  final title = find.byKey(«<<titleKey>>»);
  expect(title, findsOneWidget, reason: 'the preview is open');
  expect(tester.widget<Text>(title).data, name);

  final page = tester.element(title);
  final route = ModalRoute.of(page)!;
  expect(
    route.settings,
    isA<Page<Object?>>(),
    reason: 'a flow page, not a pushed route',
  );
  expect(route.settings.name, 'preview');
  expect(route.settings.arguments, id);
  expect(
    Navigator.of(page),
    isNot(same(Navigator.of(page, rootNavigator: true))),
    reason: 'the preview is in the flow, not on the app navigator',
  );
  expect(
    find.byKey(ValueKey(id)),
    findsOneWidget,
    reason: 'the preview page is keyed by the selected id',
  );

''')}${commentLines(m.text('step.preview_for.art', m.sections.isEmpty ? "The ${m.item}'s own art in this preview's Scaffold." : "The ${m.item}'s own art in this preview's Scaffold (the ${m.sections.first.words}\nbelow it show ${m.sections.first.image}s of their own)."), indent: '  ')}${t(r'''  final art = find.descendant(
    of: find.descendant(
      of: find.ancestor(of: title, matching: find.byType(Scaffold)),
      matching: find.byKey(«<<artKey>>»),
    ),
    matching: find.byType(Image),
  );
  expect(tester.widget<Image>(art).image, «bundledArtFor»(record.<<recordImage>>));
}''')}',
      imports: [barrel, material],
    ),
    'i_tap_and_in_quick_succession': _Step(
      t(
        'Two tiles tapped within one frame, before the first tap\'s preview exists:\n'
        'both taps reach the list, so both preview events reach the bloc. (Once the\n'
        'preview route is pushed, its modal barrier takes every tap until it\n'
        'settles, so this is the window where a second tap can land.)',
      ),
      'WidgetTester tester,\n  String first,\n  String second,',
      t(r'''{
  final a = find.text(first).hitTestable();
  final b = find.text(second).hitTestable();
  expect(a, findsOneWidget, reason: 'exactly one tappable "$first"');
  expect(b, findsOneWidget, reason: 'exactly one tappable "$second"');

  await tester.tap(a);
  await tester.tap(b);
  await «mcSettle»(tester);
}'''),
    ),
    'i_see_the_first_${items}_in_${snakeCase(m.titleField)}_order_with_their_bundled_art':
        _Step(
          t(
            'The grid holds exactly [count] <<items>>, and walking it with real drags\n'
            'shows them as media cards in the fixture\'s <<recordTitle>> order, each drawing the\n'
            'bundled asset of its own <<recordImage>> (not the fallback).',
          ),
          'WidgetTester tester,\n  int count,',
          t(r'''{
  expect(«<<shown>>»(tester), count, reason: 'the grid holds one page');
  final expected = «<<records>>».take(count).toList();
  final seen = <String>[];
  for (var drags = 0; seen.length < count; drags++) {
    if (drags > 100) {
      fail('saw ${seen.length} of $count <<items>> after 100 drags: $seen');
    }
    final cards = find.descendant(
      of: find.byKey(«<<gridKey>>»),
      matching: find.byType(«McMediaCard»),
    );
    for (final element in cards.evaluate()) {
      final card = element.widget as «McMediaCard»;
      if (seen.contains(card.title) || seen.length >= count) {
        continue;
      }
      final record = expected[seen.length];
      expect(card.title, record.<<recordTitle>>, reason: 'card ${seen.length + 1}');
      expect(card.image, record.<<recordImage>>, reason: '${record.<<recordTitle>>} art');
      final image = find.descendant(
        of: find.byElementPredicate((e) => identical(e, element)),
        matching: find.byType(Image),
      );
      expect(
        tester.widget<Image>(image).image,
        «bundledArtFor»(record.<<recordImage>>),
        reason: '${record.<<recordTitle>>} draws its bundled asset',
      );
      seen.add(card.title!);
    }
    if (seen.length < count) {
      await tester.drag(«<<scrollable>>»(), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(seen, [for (final c in expected) c.<<recordTitle>>]);
}'''),
          imports: [material],
        ),
  };

  // The navigator contract: one step per method the preview's actions and
  // sections call.
  final calls = <String, (String id, String lookup, String param)>{
    for (final a in m.actions)
      a.calls: (
        m.listEntityId,
        '${m.itemCamel}${participle(m.tests.record.title)}',
        m.tests.record.title,
      ),
    for (final s in m.sections)
      s.calls: (
        m.idOf(s.entity)!,
        '${camelCase(s.item.replaceAll(' ', '_'))}${participle(m.tests.sectionRecords[s.name]!.title)}',
        m.tests.sectionRecords[s.name]!.title,
      ),
  };
  calls.forEach((method, c) {
    final (id, lookup, param) = c;
    out['the_app_was_asked_to_${snakeCase(method)}'] = _Step(
      'The navigator contract: `$method` with [$param]\'s id, exactly once,\n'
          'and nothing else.',
      'WidgetTester tester,\n  String $param,',
      tpl(
        '''{
  final navigator = «<<nav>>»();
  final id = $id(«$lookup»($param).id);
  verify(() => navigator.$method(id)).called(1);
  verifyNoMoreInteractions(navigator);
}''',
        v,
      ),
      imports: [barrel, 'package:mocktail/mocktail.dart'],
    );
  });

  // List actions: the navigator call (no argument), and the double tap.
  for (final a in m.listActions) {
    out['the_app_was_asked_to_${a.phrase.replaceAll(' ', '_')}'] = _Step(
      'The navigator contract: `${a.calls}` exactly once, and nothing else.',
      'WidgetTester tester',
      tpl('''{
  final navigator = «<<nav>>»();
  verify(navigator.${a.calls}).called(1);
  verifyNoMoreInteractions(navigator);
}''', v),
      imports: ['package:mocktail/mocktail.dart'],
    );
  }
  if (m.listActions.isNotEmpty) {
    out['i_tap_the_icon_button_twice_in_quick_succession'] = _Step(
      "Two taps within one frame, before the first tap's effect is drawn: both\n"
          'reach the button, so both events reach its bloc.',
      'WidgetTester tester,\n  String label,',
      t(r'''{
  final target = find.byTooltip(label).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one icon button "$label"');
  await tester.tap(target);
  await tester.tap(target);
  await «mcSettle»(tester);
}'''),
    );
  }

  // Filters: open the list with one, and check it lists only its records.
  for (final f in m.filters) {
    if (f.type.name != 'String') continue;
    final what = words(f.query);
    final param = camelCase(f.query);
    final w = {
      ...v,
      'arg': f.arg,
      'name': f.name,
      'param': param,
      'what': what,
      'field': m.tests.filterRecords[f.name] ?? f.query,
      'fixture': m.text('step.filter.${f.name}.records', 'the fixture'),
    };
    out['i_open_the_${list}_for_${what.replaceAll(' ', '_')}'] = _Step(
      tpl("Enters the feature with the flow's `<<arg>>` set to [<<name>>].", w),
      'WidgetTester tester,\n  String ${f.name},',
      tpl(r'''{
  await «initFlow»(
    tester,
    () => «<<host>>»(
      <<flow>>(
        navigator: «<<nav>>»(),
        <<arg>>: <<name>>,
      ),
    ),
  );
  await «mcSettle»(tester);
}''', w),
      imports: [barrel],
    );
    out['the_${list}_shows_the_first_${items}_of_${what.replaceAll(' ', '_')}'] =
        _Step(
          tpl(
            'The grid is not empty, and walking it with real drags shows exactly the\n'
            'first [count] <<items>> of [<<param>>] in <<recordTitle>> order: every card is one of\n'
            "that <<what>>'s, and none of another <<what>>'s comes between them.",
            w,
          ),
          'WidgetTester tester,\n  int count,\n  String $param,',
          tpl(r'''{
  final expected = [
    for (final c in «<<records>>»)
      if (c.<<field>> == <<param>>) c.<<recordTitle>>,
  ].take(count).toList();
  expect(expected, hasLength(count), reason: '<<fixture>> has $count of $<<param>>');
  final seen = <String>[];
  for (var drags = 0; seen.length < count; drags++) {
    if (drags > 100) {
      fail('saw ${seen.length} of $count <<items>> after 100 drags: $seen');
    }
    final cards = find.descendant(
      of: find.byKey(«<<gridKey>>»),
      matching: find.byType(«McMediaCard»),
    );
    for (final element in cards.evaluate()) {
      final title = (element.widget as «McMediaCard»).title!;
      if (!seen.contains(title) && seen.length < count) {
        seen.add(title);
      }
    }
    if (seen.length < count) {
      await tester.drag(«<<scrollable>>»(), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(seen, expected);
}''', w),
        );
  }

  if (m.sections.isNotEmpty) {
    out['i_scroll_the_preview_until_i_see'] = _Step(
      'Real drags of the preview page until [text] is on screen.',
      'WidgetTester tester,\n  String text,',
      t(r'''{
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: «previewScrollable»().first,
  );
  await «mcSettle»(tester);
}'''),
    );
  }
  for (final s in m.sections) {
    final r = m.tests.sectionRecords[s.name]!;
    out['i_see_the_${s.words.replaceAll(' ', '_')}_of'] = _Step(
      "The preview's ${s.items} section lists exactly the first ${_number(s.limit)} ${s.items} the\n"
          '${m.item} appears in (from the ${s.items} fixture), in ${r.title} order.',
      'WidgetTester tester, String name',
      tpl(
        r'''{
  final section = find.byKey(«<<sectionKey>>»);
  await tester.scrollUntilVisible(
    section,
    200,
    scrollable: «previewScrollable»().first,
  );
  await tester.pumpAndSettle();
  final titles = [
    for (final element
        in find
            .descendant(of: section, matching: find.byType(ListTile))
            .evaluate())
      ((element.widget as ListTile).title! as Text).data,
  ];
  final records = «<<sectionOf>>»(name);
  final expected = [for (final c in records) c.<<sectionTitle>>];
  expect(expected, isNotEmpty, reason: '$name appears in some <<sectionItem>>');
  expect(titles, expected, reason: "$name's <<sectionItems>>, in <<sectionTitle>> order");
  // Each row shows that <<sectionItem>>'s <<sectionImage>>, drawn from its bundled asset.
  final tiles = find
      .descendant(of: section, matching: find.byType(ListTile))
      .evaluate()
      .toList();
  for (final (i, record) in records.indexed) {
    final art = find.descendant(
      of: find.byElementPredicate((e) => identical(e, tiles[i])),
      matching: find.byType(Image),
    );
    expect(
      tester.widget<Image>(art).image,
      «bundledArtFor»(record.<<sectionImage>>),
      reason: '${record.<<sectionTitle>>} shows its <<sectionImage>>',
    );
  }
}''',
        {
          ...v,
          'sectionKey': '${s.camel}Key',
          'sectionOf': '${s.camel}Of',
          'sectionTitle': r.title,
          'sectionImage': r.image,
          'sectionItem': s.item,
          'sectionItems': s.items,
        },
      ),
      imports: [material],
    );
  }
  return out;
}

String _number(int n) =>
    const [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
    ].elementAtOrNull(n) ??
    '$n';

/// The test environment, written once (owned): what every step shares, plus
/// the fixture lookups, which only a human knows how to write well.
DartLibrary _env(LdModel m, Map<String, String> v, String barrel) {
  final env = m.tests.env;
  String need(String key) =>
      env[key] ??
      (throw StateError(
        '${m.spec.file}: options.tests.env.$key is needed for the test env\'s first write',
      ));
  final fixturePackages = [
    for (final p in need('fixture_packages').split(RegExp(r'[,\s]+')))
      if (p.isNotEmpty) p,
  ];
  final filters = [
    for (final f in m.filters) '  ${f.type} ${f.name},',
  ].join('\n');
  final sectionHelpers = [
    for (final s in m.sections)
      tpl(
        '''
/// What the preview lists for [name]: the first ${s.limit} ${s.items}.
List<dynamic> ${s.camel}Of(String name) =>
    throw UnimplementedError('${s.camel}Of: look the ${s.items} up in their fixture');

/// The ${s.item} titled [title].
dynamic ${camelCase(s.item.replaceAll(' ', '_'))}${participle(m.tests.sectionRecords[s.name]!.title)}(String title) =>
    throw UnimplementedError('look the ${s.item} up in its fixture');
''',
        v,
      ),
  ].join('\n');
  final previewScrollable = m.sections.isEmpty
      ? ''
      : tpl(
          '''
/// The preview page's own scrollable.
Finder previewScrollable() => find.ancestor(
  of: find.byKey(${m.sections.first.camel}Key),
  matching: find.byType(Scrollable),
);

''',
          v,
        );
  final sectionKeys = [
    for (final s in m.sections)
      "const ${s.camel}Key = ValueKey<String>('${m.module}.preview.${s.key}');",
  ].join('\n');
  final text =
      tpl(
            r'''
/// The app's side of the feature contract, doubled (plan 05 §3.5).
class <<mockNav>> extends «Mock» implements <<navigator>> {}

final Expando<<<mockNav>>> _navigators = Expando('<<module>> navigator');
final Expando<double> _scrollOffsets = Expando('<<module>> scroll');

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub.
<<mockNav>> <<nav>>() =>
    _navigators[«McTestSession».current] ??= <<mockNav>>();

/// Where a step left the grid's scroll position, for a later step to compare.
double? rememberedScrollOffset() => _scrollOffsets[«McTestSession».current];

void rememberScrollOffset(double pixels) =>
    _scrollOffsets[«McTestSession».current] = pixels;

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const <<gridKey>> = ValueKey<String>('<<module>>.grid');
const <<titleKey>> = ValueKey<String>('<<module>>.preview.title');
const <<artKey>> = ValueKey<String>('<<module>>.preview.art');
SECTION_KEYS

/// What the flow state selects, as the tests see it.
typedef FlowStateView = ({
FILTERS
  ({<<Id>> id, String <<title>>})? preview,
});

/// The flow's current state, through `mc_feature_flow`'s public test hook.
/// The state type is package-private (R4; R7 keeps `src/` out of BDD tests),
/// so the hook is asked for `dynamic`.
FlowStateView <<flowState>>(WidgetTester tester) {
  final grid = find.byKey(<<gridKey>>, skipOffstage: false);
  expect(grid, findsOneWidget, reason: 'the <<module>> flow is open');
  final dynamic state = «flowStateOf»<dynamic>(tester.element(grid));
  final dynamic preview = state.preview;
  return (
FILTER_READS
    preview: preview == null
        ? null
        : (id: preview.id as <<Id>>, <<title>>: preview.<<title>> as String),
  );
}

/// The grid's own scrollable.
Finder <<scrollable>>() => find.descendant(
  of: find.byKey(<<gridKey>>),
  matching: find.byType(Scrollable),
);

ScrollPosition <<position>>(WidgetTester tester) =>
    tester.state<ScrollableState>(<<scrollable>>()).position;

/// How many <<items>> the grid holds (built or not): its child count.
int <<shown>>(WidgetTester tester) {
  final grid = tester.widget<SliverGrid>(
    find.descendant(
      of: find.byKey(<<gridKey>>),
      matching: find.byType(SliverGrid),
    ),
  );
  return (grid.delegate as SliverChildBuilderDelegate).childCount!;
}

/// Test-facing facts come from the fixture package, never from feature code:
/// the default set's records, in list order.
final List<RECORD_TYPE> <<records>> = RECORDS;

RECORD_TYPE <<lookup>>(String <<recordTitle>>) =>
    <<records>>.firstWhere((r) => r.<<recordTitle>> == <<recordTitle>>);

SECTION_HELPERSPREVIEW_SCROLLABLE/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget <<host>>(Widget flow, {AssetBundle? bundle}) => «McMediaScope»(
  resolver: const «BundledImageResolver»(),
  child: DefaultAssetBundle(
    bundle: bundle ?? «McFixtureAssetBundle»(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget <<underTest>>() => <<flow>>(navigator: <<nav>>());

/// The art [image] is drawn from: the bundled asset of its fixture path.
AssetImage bundledArtFor(«ApiImage» image) {
  final resolved = const «BundledImageResolver»().resolve(image);
  return switch (resolved) {
    «AssetResolvedImage»(:final key, :final package) => AssetImage(
      key,
      package: package,
    ),
    «NetworkResolvedImage»() => throw StateError('not bundled: $image'),
  };
}

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
FIXTURE_SETS
}''',
            v,
          )
          .replaceFirst(
            'SECTION_KEYS',
            sectionKeys.isEmpty ? '' : '$sectionKeys\n',
          )
          .replaceFirst('\nFILTERS\n', filters.isEmpty ? '\n' : '\n$filters\n')
          .replaceFirst(
            'FILTER_READS\n',
            [
              for (final f in m.filters)
                '    ${f.name}: state.${f.name} as ${f.type},\n',
            ].join(),
          )
          .replaceAll('RECORD_TYPE', need('record_type'))
          .replaceFirst('RECORDS', need('records'))
          .replaceFirst(
            'SECTION_HELPERS',
            sectionHelpers.isEmpty ? '' : '$sectionHelpers\n',
          )
          .replaceFirst('PREVIEW_SCROLLABLE', previewScrollable)
          .replaceFirst(
            'FIXTURE_SETS',
            [
              for (final s in need(
                'fixture_set_lists',
              ).split(RegExp(r'[,\s]+')))
                if (s.isNotEmpty) '  $s.forEach(«McFixtureSets».register);',
            ].map(templateRefs).join('\n'),
          );
  return DartLibrary(
    'test/feature/util/${m.module}_env.dart',
    imports: [
      barrel,
      material,
      flutterTest,
      'package:mc_feature_flow/testing.dart',
      for (final p in fixturePackages) 'package:$p/$p.dart',
    ],
    decls: [RawDecl(Code(text), name: 'bddSetUpAll')],
  );
}

/// What the env declares besides `bddSetUpAll`, for steps to reference.
List<String> _envNames(LdModel m, Map<String, String> v) => [
  v['mockNav']!,
  v['nav']!,
  'rememberedScrollOffset',
  'rememberScrollOffset',
  v['gridKey']!,
  v['titleKey']!,
  v['artKey']!,
  'FlowStateView',
  v['flowState']!,
  v['scrollable']!,
  v['position']!,
  v['shown']!,
  v['records']!,
  v['lookup']!,
  for (final s in m.sections) ...[
    '${s.camel}Key',
    '${s.camel}Of',
    '${camelCase(s.item.replaceAll(' ', '_'))}${participle(m.tests.sectionRecords[s.name]!.title)}',
  ],
  if (m.sections.isNotEmpty) 'previewScrollable',
  v['host']!,
  v['underTest']!,
  'bundledArtFor',
];

DartLibrary _flowScopeTest(LdModel m, Map<String, String> v, String barrel) {
  final fixtureSets = [
    for (final s in m.tests.fixtureSets) "..useFixtureSet('$s')",
  ];
  String useSets(String receiver) => fixtureSets.length == 1
      ? '$receiver.backend.useFixtureSet(\'${m.tests.fixtureSets.single}\');'
      : '$receiver.backend\n    ${fixtureSets.join('\n    ')};';
  final filterTests = [
    for (final f in m.filters)
      if (f.type.name == 'String')
        // A raw string drops a newline right after its opening quotes.
        '\n${tpl(
          r'''

  «mcTestWidgets»(
    '<<tag>>a new <<arg>> builds a new flow that lists that <<what>>',
    (tester) async {
      final backend = «McTestSession».current.backend
        <<sets>>;
      final <<var>> = ValueNotifier<String>('red');
      addTearDown(<<var>>.dispose);
      await «initFlow»(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: <<var>>,
          builder: (context, id, _) => «<<host>>»(
            <<flow>>(
              navigator: «<<nav>>»(),
              <<arg>>: id,
            ),
          ),
        ),
      );
      await «mcSettle»(tester);
      expect(«<<flowState>>»(tester).<<name>>, 'red');

      <<var>>.value = 'blue';
      await «mcSettle»(tester);

      expect(«<<flowState>>»(tester).<<name>>, 'blue');
      expect(
        [for (final r in backend.requests) r.query['<<query>>']],
        [
          'red',
          'blue',
        ],
      );
    },
  );''',
          {
            ...v,
            'tag': m.tag('flow_scope.filter.${f.name}'),
            'arg': f.arg,
            'what': words(f.query),
            'var': f.query,
            'name': f.name,
            'query': f.query,
            'sets': fixtureSets.join('\n        '),
          },
        )}',
  ].join();
  final body =
      tpl(
            r'''
void main() {
  setUpAll(«bddSetUpAll»);

  «mcTestWidgets»(
    "<<tagResolves>>the flow's container resolves every registration",
    (tester) async {
      USE_SETS
      await «initFlow»(
        tester,
        () => «<<host>>»(«<<underTest>>»()),
      );
      await «mcSettle»(tester);

      final page = tester.element(find.byKey(«<<gridKey>>»));
RESOLVE_COMMENT
      await page.debugResolveAll«!McFlowContext»();
      await «mcSettle»(tester);
    },
  );FILTER_TESTS

  «mcTestWidgets»(
    '<<tagRoot>>a root without a forwarded type fails naming it',
    (tester) async {
      final session = «McTestSession».current;
      // A root with Dio but no Monitoring, which the flow forwards.
      await «initializeDIContainer»([
        «McDIInitializer»(
          (getIt, _) => getIt.registerSingleton<«Dio»>(
            session.backend.backend.createDio(),
          ),
        ),
      ]);
      await tester.pumpWidget(
        «McTestApp»(
          session: session,
          home: «<<host>>»(«<<underTest>>»()),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<Monitoring>'));
      expect(find.byKey(«<<gridKey>>»), findsNothing);
    },
  );

  «mcTestWidgets»(
    '<<tagAppBar>>the list page uses McAppBar with McFlowBackButton as leading',
    (tester) async {
      USE_SETS
      await «initFlow»(
        tester,
        () => «<<host>>»(«<<underTest>>»()),
      );
      await «mcSettle»(tester);

      final bar = tester.widget<«McAppBar»>(find.byType(«McAppBar»));
      expect(bar.leading, isA<«McFlowBackButton»>());
      // The DS bar draws the flow's widget inside its own AppBar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(«McFlowBackButton»),
        ),
        findsOneWidget,
      );
      expect(find.text('<<listTitle>>'), findsOneWidget);
    },
  );
}''',
            {
              ...v,
              'tagResolves': m.tag('flow_scope.resolves'),
              'tagRoot': m.tag('flow_scope.root'),
              'tagAppBar': m.tag('flow_scope.app_bar'),
            },
          )
          .replaceAll(
            'USE_SETS',
            templateRefs(useSets('«McTestSession».current')),
          )
          .replaceFirst(
            'RESOLVE_COMMENT\n',
            commentLines(
              m.text(
                'flow_scope.resolve_comment',
                'Navigator, API, repository and the list bloc; the preview bloc takes\n'
                    'a factory parameter and is skipped by design (F-0018 fact 5).',
              ),
              indent: '      ',
            ),
          )
          .replaceFirst('FILTER_TESTS', filterTests);
  return DartLibrary(
    'test/flow_scope_test.dart',
    preamble: commentLines(
      m.text(
        'flow_scope_test.preamble',
        'The flow as a unit of wiring, entered through the barrel only. R17: the\n'
            'root imports (lib/src/di/flow_scope.dart) are complete, and a missing one\n'
            'fails at flow creation, naming the type.',
      ),
    ),
    imports: [
      if (filterTests.isNotEmpty) barrel,
      material,
      flutterTest,
    ],
    decls: [RawDecl(Code(body))],
  );
}

DartLibrary _architectureTest(LdModel m) {
  final barrelIds = <String>{
    for (final o in m.spec.navigator!.outbound) ...o.args,
  };
  final shown = [
    m.flow,
    m.navigator,
    for (final id in barrelIds) id,
  ];
  final expected = [
    for (final s in shown)
      '${switch (m.optionalText('architecture.export.$s')) {
            null => '',
            final t => commentLines(t, indent: '      '),
          }}'
          "      '$s',",
  ].join('\n');
  final tag = m.tag('architecture');
  final text = tpl(
    r'''
/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => '<<moduleDir>>/$rel';

/// One export directive, in either quote style, with an optional `show`.
final RegExp _export = RegExp(
  r\'\'\'export\s+(['"])([^'"]+)\1\s*(show\s+([^;]+))?;\'\'\',
  multiLine: true,
);

/// Any export directive at all, to check [_export] understood each one.
final RegExp _anyExport = RegExp(r'^\s*export\b', multiLine: true);

/// A Flutter import or export, in either quote style.
final RegExp _flutter = RegExp(
  r\'\'\'(import|export)\s+['"](package:flutter[a-z_]*/|dart:ui)\'\'\',
);

void main() {
  test('<<tag>>the barrel exports only the flow, the navigator and its '
      'argument type, each with show', () {
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
    expect(shown, {
EXPECTED
    });
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

    expect(files, hasLength(greaterThan(10)));
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
}''',
    {
      'moduleDir': m.spec.moduleDir,
      'module': m.module,
      'tag': tag,
    },
  ).replaceAll(r"\'\'\'", "'''").replaceFirst('EXPECTED', expected);
  return DartLibrary(
    'test/architecture/architecture_test.dart',
    preamble: commentLines(
      m.text(
        'architecture_test.preamble',
        "Conformance of the package's shape (plan 01 §3.3), not a test of feature\n"
            'behaviour: R4 (the barrel) and R15 (generators read Flutter-free files).',
      ),
    ),
    imports: ['dart:io', 'package:test/test.dart'],
    decls: [RawDecl(Code(text))],
  );
}

/// The contract test's first write (owned afterwards): every served item of
/// the list and of each section round-trips through its DTO, and the mapper
/// keeps the id, the title and the image.
DartLibrary _contractTest(LdModel m, Map<String, String> v) {
  final env = m.tests.env;
  String need(String key) =>
      env[key] ??
      (throw StateError(
        '${m.spec.file}: options.tests.env.$key is needed for the contract test\'s first write',
      ));
  final listDto = m.mappers.firstWhere((x) => x.to == m.listEntity).dto;
  final list = m.endpoint(m.listEndpoint);
  final groups = StringBuffer()
    ..write(
      tpl(
        r'''
  group('<<tag>><<dto>> against the fixture JSON', () {
    test('every served item round-trips byte for byte', () async {
      final body = await _get('/<<path>>', {'offset': 0, 'limit': <<limit>>}, const <<domain>>());
      final page = «ApiPage»<«<<dto>>»>.fromJson(
        body,
        (json) => «<<dto>>».fromJson(json! as Map<String, dynamic>),
      );

      expect(page.results, isNotEmpty);
      expect(
        «canonicalJson»([for (final dto in page.results) dto.toJson()]),
        «canonicalJson»(body['results']),
      );
    });

    test('the mapper keeps the id, the <<title>> and the image', () async {
      final body = await _get('/<<path>>', {'offset': 0, 'limit': <<limit>>}, const <<domain>>());
      final dto = «<<dto>>».fromJson(
        (body['results'] as List<Object?>).first! as Map<String, dynamic>,
      );
      final item = dto.toDomain«!<<dto>>Mapper»();

      expect(item.id, «<<Id>>»(dto.id));
      expect(item.<<title>>, isNotEmpty);
      expect(item.<<image>>, isA<«ApiImage»>());
    });
  });
''',
        {
          ...v,
          'tag': m.tag('contract'),
          'dto': listDto,
          'path': list.urlPath,
          'limit': '${m.pageSize}',
          'domain': need('mock_domain'),
          'image': m.imageField,
        },
      ),
    );
  for (final s in m.sections) {
    final dto = m.mappers.firstWhere((x) => x.to == s.entity).dto;
    groups.write(
      tpl(
        r'''

  group('<<tag>><<dto>> against the fixture JSON', () {
    test('every served item round-trips byte for byte', () async {
      final body = await _get('/<<path>>', {'<<by>>': <<value>>, 'limit': <<limit>>}, const <<domain>>());
      final page = «ApiPage»<«<<dto>>»>.fromJson(
        body,
        (json) => «<<dto>>».fromJson(json! as Map<String, dynamic>),
      );

      expect(page.results, isNotEmpty);
      expect(
        «canonicalJson»([for (final dto in page.results) dto.toJson()]),
        «canonicalJson»(body['results']),
      );
    });
  });
''',
        {
          ...v,
          'tag': m.tag('contract.${s.name}'),
          'dto': dto,
          'path': m.endpoint(s.endpoint).urlPath,
          'by': s.by,
          'value': need('${s.name}.by'),
          'limit': '${s.limit}',
          'domain': need('${s.name}.mock_domain'),
        },
      ),
    );
  }
  final fixturePackages = [
    for (final p in need('fixture_packages').split(RegExp(r'[,\s]+')))
      if (p.isNotEmpty) p,
  ];
  return DartLibrary(
    'test/contract/${snakeCase(m.items.replaceAll(' ', '_'))}_api_contract_test.dart',
    preamble: '// Contract tests are the one place a feature test reaches `src/` (R7).\n',
    imports: [
      flutterTest,
      for (final p in fixturePackages) 'package:$p/$p.dart',
      'package:mc_media/mc_media.dart',
    ],
    decls: [
      RawDecl(
        Code(
          tpl(
            r'''
Future<Map<String, dynamic>> _get(
  String path,
  Map<String, Object> query,
  «MockDomain» domain,
) async {
  final dio = «MockBackend»(domains: [domain]).createDio();
  final response = await dio.get<Map<String, dynamic>>(
    path,
    queryParameters: query,
  );
  return response.data!;
}

void main() {
GROUPS}''',
            v,
          ).replaceFirst('GROUPS', '$groups'),
        ),
      ),
    ],
  );
}
