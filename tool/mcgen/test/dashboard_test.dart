// T-0076: the dashboard archetype (P2-06). Its exemplar, feature/store/
// store_home, is its golden: the render must equal the exemplar outside keep
// regions and owned files (plan 02 KD1, ADR-0017). It is the only DB module,
// so the throwaway probes (tool/T-0076-AC3_db_probe.sh) carry the
// generalisation proof under Bazel; here, lint must reject a spec that gets
// any role the emitters read wrong.

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _rel = 'feature/store/store_home';

Directory _copyRoot(String tag, {String Function(String)? edit}) {
  final root = tempRoot(tag);
  for (final d in Directory(p.join(repoRoot, 'utility')).listSync()) {
    final pubspec = File(p.join(d.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      writeFile(
        root,
        'utility/${p.basename(d.path)}/pubspec.yaml',
        pubspec.readAsStringSync(),
      );
    }
  }
  final source = p.join(repoRoot, _rel);
  for (final f in listTree(source)) {
    final out = File(p.join(root.path, _rel, f));
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(File(p.join(source, f)).readAsBytesSync());
  }
  if (edit != null) {
    final spec = File(p.join(root.path, _rel, 'mcgen.yaml'));
    final before = spec.readAsStringSync();
    final after = edit(before);
    expect(after, isNot(before), reason: 'the edit changed the spec');
    spec.writeAsStringSync(after);
  }
  addTearDown(() => root.deleteSync(recursive: true));
  return root;
}

Generator get _generator {
  final tool = ToolLayout(mcgenDir);
  final cfg = tool.loadConfig();
  return Generator(
    config: cfg,
    archetypes: archetypes,
    bricks: BrickSet(tool.bricksDir),
    formatter: DartFormatter(cfg),
  );
}

GeneratedModule _render(String root) => _generator.generate(
  loadSpec(
    text: File(p.join(root, _rel, 'mcgen.yaml')).readAsStringSync(),
    file: '$_rel/mcgen.yaml',
    schema: schema,
  ),
  index: RepoIndex.scan(root),
  forbidden: [root, mcgenDir],
);

/// The lint errors [edit] causes, as `path: message` texts.
List<String> _lint(String tag, String Function(String) edit) {
  final root = _copyRoot(tag, edit: edit);
  final r = mcgen(['spec', 'lint', '--root', root.path, 'store_home']);
  expect(r.code, 1, reason: '$r');
  return [
    for (final l in r.err.trim().split('\n'))
      if (l.contains('error [dashboard]'))
        l.substring(
          l.indexOf('error [dashboard]') + 'error [dashboard] '.length,
        ),
  ];
}

void main() {
  group('T-0076-AC1 the exemplar round-trips', () {
    test('T-0076-AC1 mcgen gen store_home --check exits 0 against the '
        'exemplar', () {
      final r = mcgen(['gen', '--check', 'store_home'], cwd: repoRoot);
      expect(r.code, 0, reason: '$r');
      expect(r.out, contains('$_rel: up to date'));
      final c = mcgen(['check', 'store_home'], cwd: repoRoot);
      expect(c.code, 0, reason: '$c');
    });

    test('T-0076-AC1 the round-trip golden: compareToExemplar finds the '
        'render identical to the real exemplar', () {
      final gen = _render(repoRoot);
      final diff = compareToExemplar(gen, p.join(repoRoot, _rel));
      expect(diff.identical, isTrue, reason: '$diff');
      for (final f in gen.files.values.where((f) => f.ownership == 'owned')) {
        expect(
          f.path,
          startsWith('test/feature/step/'),
          reason: 'only step stubs are emitted as owned: ${f.path}',
        );
      }
      for (final f in [
        'lib/src/presentation/bloc/banners_bloc.dart',
        'lib/src/presentation/bloc/cart_summary_bloc.dart',
        'lib/src/presentation/bloc/category_products_bloc.dart',
        'lib/src/presentation/bloc/store_section_bloc.dart',
        'lib/src/presentation/page/store_home_page.dart',
        'lib/src/flow/store_home_flow.dart',
        'lib/src/l10n/store_home_de.arb',
        'pubspec.yaml',
        'test/architecture/architecture_test.dart',
      ]) {
        expect(gen.files.keys, contains(f));
        expect(gen.files[f]!.ownership, 'managed');
      }
    });

    test('T-0076-AC1 a changed spec field makes --check exit 1 and name the '
        'file', () {
      final root = _copyRoot(
        'change',
        edit: (s) => s.replaceFirst('de: "Shop"', 'de: "Laden"'),
      );
      final r = mcgen(['gen', '--check', '--root', root.path, 'store_home']);
      expect(r.code, 1, reason: '$r');
      expect('${r.out}${r.err}', contains('store_home_de.arb'));
    });

    test('T-0076-AC1 an edit inside a keep region keeps --check green; an '
        'edit outside one fails it', () {
      final root = _copyRoot('keep');
      final f = File(
        p.join(root.path, _rel, 'lib/src/presentation/bloc/deals_bloc.dart'),
      );
      final text = f.readAsStringSync();
      f.writeAsStringSync(
        text.replaceFirst(
          '_navigator.openComic(id);\n',
          '_navigator.openComic(id); // hand edit\n',
        ),
      );
      expect(
        mcgen(['gen', '--check', '--root', root.path, 'store_home']).code,
        0,
      );
      f.writeAsStringSync(
        f.readAsStringSync().replaceFirst(
          'class DealsBloc',
          'class DealsBloc // outside',
        ),
      );
      final r = mcgen(['gen', '--check', '--root', root.path, 'store_home']);
      expect(r.code, 1, reason: '$r');
      expect('${r.out}${r.err}', contains('deals_bloc.dart'));
    });
  });

  group('T-0076-AC2 what is rendered and what is kept', () {
    test('T-0076-AC2 the keep regions are the taps and the banner helper, '
        'and the hand-written files are owned, not rendered', () {
      final gen = _render(repoRoot);
      final regions = <String>{
        for (final f in gen.files.values)
          for (final m in RegExp(r'// mcgen:keep (\S+)').allMatches(f.content))
            m[1]!,
      };
      expect(regions, {
        'banners.open',
        'banners.members',
        'categories.open',
        'deals.open',
        'featured.open',
      });
      for (final owned in [
        'BUILD.bazel',
        'lib/src/domain/model/store.dart',
        'lib/src/domain/repository/store_home_repository.dart',
        'lib/src/presentation/widget/banners_section.dart',
        'test/feature/util/store_home_env.dart',
        'test/flow_scope_test.dart',
      ]) {
        expect(gen.files.keys, isNot(contains(owned)));
      }
    });

    test('T-0076-AC2 gen writes only the manifest into the exemplar, and the '
        'committed manifest is the one it writes', () {
      final root = _copyRoot('manifest');
      final before = {
        for (final f in listTree(p.join(root.path, _rel)))
          if (!f.startsWith('.mcgen'))
            f: File(p.join(root.path, _rel, f)).readAsBytesSync().length,
      };
      final r = mcgen(['gen', '--root', root.path, 'store_home']);
      expect(r.code, 0, reason: '$r');
      expect({
        for (final f in listTree(p.join(root.path, _rel)))
          if (!f.startsWith('.mcgen'))
            f: File(p.join(root.path, _rel, f)).readAsBytesSync().length,
      }, before);
      expect(
        readFile(root, '$_rel/.mcgen/manifest.json'),
        File(p.join(repoRoot, _rel, '.mcgen/manifest.json')).readAsStringSync(),
      );
    });
  });

  group('T-0076-AC3 lint rejects a spec that gets a role wrong', () {
    test('T-0076-AC3 an unknown option and a bad section key', () {
      expect(
        _lint(
          'l1',
          (s) => s.replaceFirst('options:\n', 'options:\n  colour: red\n'),
        ),
        contains('options.colour: unknown key "colour"'),
      );
      expect(
        _lint(
          'l2',
          (s) => s.replaceFirst('      kind: session\n', '      kind: wide\n'),
        ),
        contains(
          'options.sections[4].kind: "kind" must be list or session, not "wide"',
        ),
      );
      expect(
        _lint(
          'l3',
          (s) => s.replaceFirst(
            '      uses: [flow, navigator]\n',
            '      uses: [flow, telepathy]\n',
          ),
        ),
        contains(
          'options.sections[0].uses: "uses" has "telepathy": it must be flow, navigator, clock or session',
        ),
      );
    });

    test('T-0076-AC3 barrel: it may export only declared ids', () {
      expect(
        _lint(
          'barrel',
          (s) => s.replaceFirst(
            'barrel: [ComicId, CategoryId]',
            'barrel: [ComicId, UserId]',
          ),
        ),
        contains(
          'options.barrel: the barrel exports "UserId", which options.ids lacks',
        ),
      );
    });

    test('T-0076-AC3 kinds: a tap kind must be declared, once', () {
      expect(
        _lint(
          'kinds',
          (s) => s.replaceFirst(
            'kinds: [comic, category, search, cart]',
            'kinds: [comic, category, search]',
          ),
        ),
        contains('options.sections[4].open_kind: options.kinds has no "cart"'),
      );
      expect(
        _lint(
          'kinds2',
          (s) => s.replaceFirst(
            'kinds: [comic, category, search, cart]',
            'kinds: [comic, comic, category, search, cart]',
          ),
        ),
        contains('options.kinds: options.kinds lists a kind twice'),
      );
    });

    test('T-0076-AC3 ids: a type, and used by a method or the detail page', () {
      expect(
        _lint(
          'ids1',
          (s) => s.replaceFirst('      type: int\n', '      type: double\n'),
        ),
        contains(
          'options.ids[1].type: an id is a String or an int, not "double"',
        ),
      );
      expect(
        _lint(
          'ids2',
          (s) => s.replaceFirst(
            '  ids:\n',
            '  ids:\n    - name: StrayId\n      type: int\n',
          ),
        ),
        contains(
          'options.ids: options.ids has "StrayId", which no navigator method and no detail page takes',
        ),
      );
      expect(
        _lint(
          'ids3',
          (s) => s.replaceFirst(
            'outbound: [openComic(ComicId)',
            'outbound: [openComic(WidgetId)',
          ),
        ),
        contains(
          'options.ids: the navigator takes "WidgetId", which options.ids lacks',
        ),
      );
    });

    test('T-0076-AC3 detail: its id, kind, call, screen and need', () {
      expect(
        _lint(
          'd1',
          (s) => s.replaceFirst('    id: CategoryId\n', '    id: ShelfId\n'),
        ),
        contains('options.detail.id: options.ids has no "ShelfId"'),
      );
      expect(
        _lint(
          'd2',
          (s) => s.replaceFirst(
            '    open_call: openComic\n',
            '    open_call: openNothing\n',
          ),
        ),
        contains(
          'options.detail.open_call: the navigator has no method "openNothing"',
        ),
      );
      expect(
        _lint(
          'd3',
          (s) =>
              s.replaceFirst('    open_kind: comic\n', '    open_kind: zap\n'),
        ),
        contains('options.detail.open_kind: options.kinds has no "zap"'),
      );
      expect(
        _lint(
          'd4',
          (s) => s.replaceFirst('detail: store_category', 'detail: store_home'),
        ),
        contains(
          'options.screens: the home and the detail page need different names',
        ),
      );
      expect(
        _lint(
          'd5',
          (s) => s.replaceFirst(
            '  screens: {home: store_home, detail: store_category}',
            '  screens: {home: store_home}',
          ),
        ),
        contains('options.screens.detail: a detail page needs its screen name'),
      );
    });

    test('T-0076-AC3 params: only navigator methods', () {
      expect(
        _lint(
          'params',
          (s) => s.replaceFirst(
            'params: {openSearch: query}',
            'params: {openNothing: query}',
          ),
        ),
        contains(
          'options.params.openNothing: the navigator has no method "openNothing"',
        ),
      );
    });

    test('T-0076-AC3 session section: its call, kind and fetch', () {
      expect(
        _lint(
          's1',
          (s) => s.replaceFirst(
            '      open_call: openCart\n',
            '      open_call: openBasket\n',
          ),
        ),
        contains(
          'options.sections[4].open_call: the navigator has no method "openBasket"',
        ),
      );
      expect(
        _lint('s2', (s) => s.replaceFirst('      fetch: fetchCart\n', '')),
        contains(
          'options.sections[4]: section "cart" needs "fetch" or "fetch_method"',
        ),
      );
      expect(
        _lint(
          's3',
          (s) => s.replaceFirst(
            '      uses: [navigator, session]\n',
            '      uses: [navigator]\n',
          ),
        ),
        contains(
          'options.sections[4].uses: a session section uses session and navigator',
        ),
      );
      expect(
        _lint(
          's4',
          (s) => s.replaceFirst(
            'requestSignIn() -> Future<bool>',
            'requestLogin() -> Future<bool>',
          ),
        ),
        contains(
          'options.sections[4] (requestSignIn): the navigator has no method "requestSignIn"',
        ),
      );
    });

    test('T-0076-AC3 list section: a tap handler, a fetch, and the flag', () {
      expect(
        _lint(
          't1',
          (s) => s.replaceFirst(
            '      open: |-\n        final id = deal.product.id;',
            '      zopen: |-\n        final id = deal.product.id;',
          ),
        ),
        contains('options.sections[1].zopen: unknown key "zopen"'),
      );
      expect(
        _lint('t2', (s) => s.replaceFirst('      fetch: fetchBanners\n', '')),
        contains(
          'options.sections[0]: section "banners" needs "fetch" or "fetch_method"',
        ),
      );
      expect(
        _lint(
          't3',
          (s) => s.replaceFirst('      flag: storeHomeFeatured\n', ''),
        ),
        contains('options.flags[0]: flag "storeHomeFeatured" gates no section'),
      );
      expect(
        _lint(
          't4',
          (s) => s.replaceFirst(
            '      flag: storeHomeFeatured\n',
            '      flag: storeHomeNothing\n',
          ),
        ),
        contains(
          'options.sections[3].flag: options.flags has no flag "storeHomeNothing"',
        ),
      );
    });

    test('T-0076-AC3 a section that uses the flow needs the detail page', () {
      expect(
        _lint('f1', (s) {
          final i = s.indexOf('  detail:\n');
          final j = s.indexOf('  sections:\n');
          return s.substring(0, i) + s.substring(j);
        }),
        contains(
          'options.sections[0].uses: section "banners" uses the flow, which holds only the detail page: options.detail is missing',
        ),
      );
    });

    test('T-0076-AC3 tests options and the strings the page reads', () {
      expect(
        _lint(
          'x1',
          (s) => s.replaceFirst(
            '    page: store\n',
            '    page: store\n    colour: red\n',
          ),
        ),
        contains(
          'options.tests.colour: unknown key "colour" (one of money, tag_barrel, tag_money, min_pure, page)',
        ),
      );
      expect(
        _lint(
          'x2',
          (s) => s.replaceFirst(
            '    - key: storeHomeTitle\n',
            '    - key: storeHomeTitleX\n',
          ),
        ),
        contains('l10n.strings: a dashboard needs the string "storeHomeTitle"'),
      );
    });

    test('T-0076-AC3 a prose slot no template uses fails gen, naming it', () {
      final root = _copyRoot(
        'prose',
        edit: (s) => s.replaceFirst(
          '  prose:\n',
          '  prose:\n    nothing.uses.this: x\n',
        ),
      );
      final r = mcgen(['gen', '--check', '--root', root.path, 'store_home']);
      expect(r.code, isNot(0), reason: '$r');
      expect('${r.out}${r.err}', contains('nothing.uses.this'));
    });
  });

  group('T-0076-AC3 the probes are not the exemplar with names swapped', () {
    Directory probe(String mod, String tag) {
      final root = tempRoot(tag);
      addTearDown(() => root.deleteSync(recursive: true));
      for (final d in Directory(p.join(repoRoot, 'utility')).listSync()) {
        final pubspec = File(p.join(d.path, 'pubspec.yaml'));
        if (pubspec.existsSync()) {
          writeFile(
            root,
            'utility/${p.basename(d.path)}/pubspec.yaml',
            pubspec.readAsStringSync(),
          );
        }
      }
      writeFile(
        root,
        'feature/zz_probe/$mod/mcgen.yaml',
        readFixture('$mod/mcgen.yaml'),
      );
      return root;
    }

    GeneratedModule gen(Directory root, String mod) => _generator.generate(
      loadSpec(
        text: readFile(root, 'feature/zz_probe/$mod/mcgen.yaml'),
        file: 'feature/zz_probe/$mod/mcgen.yaml',
        schema: schema,
      ),
      index: RepoIndex.scan(root.path),
      forbidden: [root.path, mcgenDir],
    );

    test('T-0076-AC3 both probe specs lint clean and render the same bytes '
        'in two roots', () {
      for (final mod in ['zz_db_a', 'zz_db_b']) {
        final a = probe(mod, '$mod-a');
        final b = probe(mod, '$mod-b');
        final lint = mcgen(['spec', 'lint', '--root', a.path, mod]);
        expect(lint.code, 0, reason: '$lint');
        final ga = gen(a, mod);
        final gb = gen(b, mod);
        expect(ga.files.keys, gb.files.keys);
        for (final k in ga.files.keys) {
          expect(ga.files[k]!.content, gb.files[k]!.content, reason: k);
        }
      }
    });

    test('T-0076-AC3 probe A has three sections and no detail page, flag or '
        'flags file; probe B has five, a flag and a paged detail page', () {
      final ga = gen(probe('zz_db_a', 'a'), 'zz_db_a');
      final blocs = [
        for (final k in ga.files.keys)
          if (k.startsWith('lib/src/presentation/bloc/') &&
              k.endsWith('_bloc.dart'))
            k,
      ];
      expect(
        blocs.map(p.basename),
        [
          'cart_summary_bloc.dart',
          'deals_bloc.dart',
          'featured_bloc.dart',
          'store_section_bloc.dart',
        ]..sort(),
      );
      expect(
        ga.files.keys,
        isNot(contains('lib/src/flags/zz_db_a_flags.dart')),
      );
      expect(ga.files.keys.where((k) => k.contains('category')), isEmpty);
      final page =
          ga.files['lib/src/presentation/page/zz_db_a_page.dart']!.content;
      expect(page, isNot(contains('FeatureFlagsReader')));
      final gb = gen(probe('zz_db_b', 'b'), 'zz_db_b');
      final pageB =
          gb.files['lib/src/presentation/page/zz_db_b_page.dart']!.content;
      expect(pageB, contains('SpotlightSection()'));
      expect(pageB, contains('if (_spotlight)'));
      expect(pageB, isNot(contains('FeaturedSection')));
      expect(
        gb
            .files['lib/src/presentation/bloc/category_products_bloc.dart']!
            .content,
        contains('PagingController<Product>'),
      );
      expect(
        gb.files['lib/src/domain/model/store_analytics.dart']!.content,
        contains("spotlight('spotlight')"),
      );
    });
  });
}
