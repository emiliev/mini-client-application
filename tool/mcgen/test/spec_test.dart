// T-0065-AC4 (spec and lint): the schema accepts plan 02's example; each
// lint rule rejects a crafted bad spec with an exact message, line and column.

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

/// A do-nothing feature archetype, so feature-tier rules can be exercised
/// before P2-04 adds the real ones.
class _StubFeature extends Archetype {
  const _StubFeature();

  @override
  String get name => 'stub_feature';

  @override
  Set<Tier> get tiers => const {Tier.feature};

  @override
  void emit(EmitContext ctx) {}
}

final _archetypes = {...archetypes, 'stub_feature': const _StubFeature()};

/// Lints [spec] at [rel] in a root that also holds [files].
Run lint(String rel, String spec, {Map<String, String> files = const {}}) {
  final root = tempRoot('lint');
  addTearDown(() => root.deleteSync(recursive: true));
  writeFile(root, rel, spec);
  files.forEach((k, v) => writeFile(root, k, v));
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runMcgen(
    ['spec', 'lint', '--root', root.path, rel],
    out: out,
    err: err,
    cwd: root.path,
    archetypes: _archetypes,
  );
  return Run(code, '$out', '$err');
}

List<String> lines(String s) =>
    s.trim().isEmpty ? const [] : s.trim().split('\n');

const _feature = '''
schema: mcgen/1
module: library_x
tier: feature
archetype: stub_feature
ownership: managed
''';

void main() {
  group('T-0065-AC4 the schema', () {
    test('T-0065-AC4 accepts the plan 02 section 2.2 example spec', () {
      final text = readFixture('plan02_example.yaml');
      final doc = parseYamlDocument(
        text,
        'feature/characters/characters_list/mcgen.yaml',
      );
      expect(schema.validate(doc, 'x'), isEmpty);
      final spec = loadSpec(
        text: text,
        file: 'feature/characters/characters_list/mcgen.yaml',
        schema: schema,
      );
      expect(spec.module, 'characters_list');
      expect(spec.tier, Tier.feature);
      expect(spec.archetype, 'list_detail');
      expect(spec.ownership, Ownership.mixed);
      expect(spec.sizeClass, 'M');
      expect(spec.deps, [
        'mc_prelude',
        'mc_di',
        'mc_api_client',
        'mc_monitoring',
        'mc_feature_flow',
        'mc_bloc_kit',
        'mc_ds_cards',
        'mc_formatters',
      ]);
      expect(
        [for (final e in spec.entities) '${e.name}:${e.kind.name}'],
        ['Character:model', 'Alignment:enumeration', 'Affiliation:union'],
      );
      expect(
        [for (final f in spec.entities[0].fields) '${f.name}: ${f.type}'],
        [
          'id: CharacterId',
          'name: String',
          'aliases: List<String>',
          'thumbnail: Thumbnail',
          'alignment: Alignment',
          'firstAppearance: DateTime?',
        ],
      );
      expect(spec.entities[0].fields[2].defaultValue, <Object?>[]);
      expect(spec.entities[0].fields[4].unknown, 'neutral');
      expect(
        [for (final v in spec.entities[2].variants) '$v'],
        ['team(TeamRef)', 'solo()', 'unknown()'],
      );
      expect(spec.entities[2].unionKey, 'kind');
      expect(
        [
          for (final e in spec.endpoints)
            '${e.method} ${e.urlPath} -> ${e.returns}',
        ],
        [
          'GET v1/characters -> Page<Character>',
          'GET v1/characters/{id} -> Character',
        ],
      );
      expect(spec.endpoints[0].query, ['offset', 'limit', 'nameStartsWith']);
      expect(spec.rules.single.examples, [
        {'comicsCount': 1200, 'expect': 'legend'},
        {'comicsCount': 5, 'expect': 'rookie'},
      ]);
      expect(spec.rules.single.cases.map((c) => '${c.when} => ${c.then}'), [
        'comicsCount >= 1000 => legend',
        'comicsCount >= 100 => veteran',
      ]);
      expect(
        [for (final e in spec.blocs.single.events) '$e'],
        ['load', 'loadMore', 'refresh', 'search(query)', 'open(Character)'],
      );
      expect(spec.blocs.single.transformers, {'search': 'debounce_300ms'});
      expect(spec.flow!.pages, ['CharactersListPage', 'CharacterPreviewPage']);
      expect('${spec.flow!.state.single.type}', 'CharacterId?');
      expect(
        [
          for (final s in spec.screens)
            '${s.name}/${s.layout}/${s.depth}/${s.widgets}',
        ],
        [
          'CharactersListPage/sliver_grid/9/7',
          'CharacterPreviewPage/scroll_sections/11/9',
        ],
      );
      expect(
        [for (final o in spec.navigator!.outbound) '$o'],
        [
          'openCharacter(CharacterId)',
          'openComic(ComicId)',
          'requestSignIn() -> bool',
        ],
      );
      expect(spec.l10n!.locales, ['en', 'de', 'fr', 'es', 'ja']);
      expect(
        [
          spec.l10n!.keys,
          spec.l10n!.placeholders,
          spec.l10n!.plurals,
          spec.l10n!.selects,
        ],
        [64, 9, 4, 1],
      );
      expect(spec.mixins.single.on, 'State');
      expect(
        [for (final s in spec.bdd.single.scenarios) s.id],
        ['MC-characters_list-01', 'MC-characters_list-02'],
      );
      expect(spec.bdd.single.outlines.single.rule, 'badge');
      expect(spec.keep, ['rules.badge.body']);
    });

    test('T-0065-AC4 against the real repo, only the archetype is unknown (P2-04 adds list_detail)', () {
      final text = readFixture('plan02_example.yaml');
      const rel = 'feature/characters/characters_list/mcgen.yaml';
      final spec = loadSpec(text: text, file: rel, schema: schema);
      final d = lintSpec(
        spec,
        LintContext(
          index: RepoIndex.scan(repoRoot),
          config: config,
          archetypes: archetypes,
        ),
      );
      expect(d.map((x) => '$x'), [
        '$rel:4:12: error [archetype] archetype: unknown archetype "list_detail" (known: utility_hello)',
      ]);
    });

    test('T-0065-AC4 the spec hash ignores comments and key order', () {
      const a =
          'schema: mcgen/1\nmodule: m\ntier: utility\narchetype: utility_hello\nownership: managed\n';
      const b =
          '# note\nownership: managed\narchetype: utility_hello\ntier: utility\nmodule: m\nschema: mcgen/1\n';
      final ha = loadSpec(
        text: a,
        file: 'utility/m/mcgen.yaml',
        schema: schema,
      ).specHash;
      final hb = loadSpec(
        text: b,
        file: 'utility/m/mcgen.yaml',
        schema: schema,
      ).specHash;
      expect(ha, hb);
      expect(
        ha,
        isNot(
          loadSpec(
            text: '${a}seed_salt: 1\n',
            file: 'utility/m/mcgen.yaml',
            schema: schema,
          ).specHash,
        ),
      );
    });

    test('T-0065-AC4 schema errors carry file, line, column and YAML path', () {
      final r = lint(
        'utility/mc_hello/mcgen.yaml',
        helloSpec
            .replaceFirst('tier: utility', 'tier: service')
            .replaceFirst(
              '{name: excited, type: bool, default: false}',
              '{name: excited, type: bool, colour: red}',
            ),
      );
      expect(r.code, 1);
      expect(lines(r.err), [
        'utility/mc_hello/mcgen.yaml:6:7: error [schema] tier: must be one of "app", "feature", "utility"',
        'utility/mc_hello/mcgen.yaml:17:37: error [schema] entities[0].fields[2].colour: unknown key "colour"',
      ]);
      expect(lines(r.out), ['mcgen spec lint: 1 spec(s), 2 error(s)']);
    });

    test('T-0065-AC4 a YAML syntax error is located', () {
      final r = lint(
        'utility/mc_hello/mcgen.yaml',
        'schema: mcgen/1\nmodule: [unclosed\n',
      );
      expect(r.code, 1);
      expect(
        lines(r.err).single,
        startsWith('utility/mc_hello/mcgen.yaml:3:1: error [yaml] '),
      );
    });

    test('T-0065-AC4 an entity needs exactly one of fields, enum, union', () {
      final r = lint(
        'utility/mc_hello/mcgen.yaml',
        helloSpec.replaceFirst(
          '    enum: [calm, cheerful]\n',
          '    enum: [calm, cheerful]\n    fields: [{name: x, type: int}]\n',
        ),
      );
      expect(lines(r.err), [
        'utility/mc_hello/mcgen.yaml:18:5: error [entity-kind] entities[1]: entity "Mood" has fields and enum; use exactly one',
      ]);
    });
  });

  group('T-0065-AC4 each lint rule rejects a crafted bad spec', () {
    test('T-0065-AC4 the reference spec is clean', () {
      final r = lint('utility/mc_hello/mcgen.yaml', helloSpec);
      expect(r.err, '');
      expect(r.code, 0);
      expect(lines(r.out), ['mcgen spec lint: 1 spec(s), 0 error(s)']);
    });

    test('T-0065-AC4 D1 layering: feature -> feature', () {
      final r = lint(
        'feature/library/library_x/mcgen.yaml',
        '${_feature}deps: [mc_prelude, comics_details]\n',
        files: {
          'utility/mc_prelude/pubspec.yaml': 'name: mc_prelude\n',
          'feature/comics/comics_details/pubspec.yaml':
              'name: comics_details\n',
        },
      );
      expect(r.code, 1);
      expect(lines(r.err), [
        'feature/library/library_x/mcgen.yaml:6:20: error [layering] deps[1]: '
            'feature → feature dependency on "comics_details" (feature/comics/comics_details); '
            'D1: features depend on utilities only',
      ]);
    });

    test(
      'T-0065-AC4 D1 layering: utility -> feature, also through dev_deps',
      () {
        final r = lint(
          'utility/mc_hello/mcgen.yaml',
          '${helloSpec}dev_deps: [comics_details]\n',
          files: {
            'feature/comics/comics_details/pubspec.yaml':
                'name: comics_details\n',
          },
        );
        expect(lines(r.err), [
          'utility/mc_hello/mcgen.yaml:22:12: error [layering] dev_deps[0]: '
              'utility → feature dependency on "comics_details" (feature/comics/comics_details); '
              'D1: utilities depend on utilities only',
        ]);
      },
    );

    test('T-0065-AC4 mc_design_system is never a direct dep', () {
      final r = lint(
        'feature/library/library_x/mcgen.yaml',
        '${_feature}deps:\n  - mc_design_system\n',
      );
      expect(lines(r.err), [
        'feature/library/library_x/mcgen.yaml:7:5: error [design-system-dep] deps[0]: '
            '"mc_design_system" is never a direct dependency; depend on the mc_ds_* kit you use',
      ]);
    });

    test('T-0065-AC4 an unknown dependency', () {
      final r = lint(
        'feature/library/library_x/mcgen.yaml',
        '${_feature}deps: [left_pad]\n',
      );
      expect(lines(r.err), [
        'feature/library/library_x/mcgen.yaml:6:8: error [unknown-dep] deps[0]: '
            '"left_pad" is not a first-party package, nor listed in tool/mcgen/mcgen.yaml third_party or sdk_packages',
      ]);
    });

    test(
      'T-0065-AC4 name collisions: types, fields, ids, and the module itself',
      () {
        final r = lint(
          'utility/mc_hello/mcgen.yaml',
          helloSpec
              .replaceFirst('  - name: Mood\n', '  - name: Greeting\n')
              .replaceFirst(
                '{name: excited, type: bool, default: false}',
                '{name: name, type: bool}',
              ),
          files: {
            'utility/elsewhere/mc_hello/pubspec.yaml': 'name: mc_hello\n',
          },
        );
        expect(lines(r.err), [
          'utility/mc_hello/mcgen.yaml:5:9: error [name-collision] module: module "mc_hello" is already the package at utility/elsewhere/mc_hello',
          'utility/mc_hello/mcgen.yaml:16:28: error [utility_hello] entities[0].fields[1].type: unknown type "Mood": use dart:core types or entities of this spec',
          'utility/mc_hello/mcgen.yaml:17:16: error [name-collision] entities[0].fields[2].name: duplicate field "name" (first at line 15)',
          'utility/mc_hello/mcgen.yaml:18:11: error [name-collision] entities[1].name: "Greeting" is already declared at line 12 (entities[0].name)',
        ]);
      },
    );

    test(
      'T-0065-AC4 name collisions: endpoint and rule ids, navigator methods',
      () {
        final r = lint('feature/library/library_x/mcgen.yaml', '''
${_feature}endpoints:
  - {id: list, method: GET, path: v1/x}
  - {id: list, method: GET, path: v1/y}
rules:
  - {id: badge, kind: classifier, examples: [{expect: a}]}
  - {id: badge, kind: classifier, examples: [{expect: b}]}
navigator: {name: XNavigator, outbound: [open(A), open(B)]}
''');
        expect(lines(r.err), [
          'feature/library/library_x/mcgen.yaml:8:10: error [name-collision] endpoints[1].id: duplicate endpoint id "list" (first at line 7)',
          'feature/library/library_x/mcgen.yaml:11:10: error [name-collision] rules[1].id: duplicate rule id "badge" (first at line 10)',
          'feature/library/library_x/mcgen.yaml:12:51: error [name-collision] navigator.outbound[1]: duplicate navigator method "open" (first at line 12)',
        ]);
      },
    );

    test('T-0065-AC4 scenario ids: format and uniqueness', () {
      final r = lint('feature/library/library_x/mcgen.yaml', '''
${_feature}rules:
  - {id: badge, kind: classifier, examples: [{expect: a}]}
bdd:
  - feature: browse
    scenarios:
      - {id: MC-library_x-01, title: ok, steps: [When I open it]}
      - {id: MC-other-02, title: wrong module, steps: [When I open it]}
      - {id: MC-library_x-1, title: one digit, steps: [When I open it]}
      - {id: MC-library_x-01, title: twice, steps: [When I open it]}
    outlines:
      - {id: MC-library_x-03, rule: nope, title: unknown rule}
''');
      expect(lines(r.err), [
        'feature/library/library_x/mcgen.yaml:12:14: error [scenario-id] bdd[0].scenarios[1].id: scenario id "MC-other-02" must match MC-library_x-NN (two or more digits)',
        'feature/library/library_x/mcgen.yaml:13:14: error [scenario-id] bdd[0].scenarios[2].id: scenario id "MC-library_x-1" must match MC-library_x-NN (two or more digits)',
        'feature/library/library_x/mcgen.yaml:14:14: error [scenario-id] bdd[0].scenarios[3].id: duplicate scenario id "MC-library_x-01" (first at line 11)',
        'feature/library/library_x/mcgen.yaml:16:37: error [rule-examples] bdd[0].outlines[0].rule: outline "MC-library_x-03" runs rule "nope", which the spec does not define',
      ]);
    });

    test('T-0065-AC4 every rule needs examples', () {
      final r = lint('feature/library/library_x/mcgen.yaml', '''
${_feature}rules:
  - id: badge
    kind: classifier
    cases: [{when: "n > 1", then: big}]
    default: small
''');
      expect(lines(r.err), [
        'feature/library/library_x/mcgen.yaml:7:9: error [rule-examples] rules[0].examples: rule "badge" has no examples; every rule needs at least one (plan 02 C8)',
      ]);
    });

    test('T-0065-AC4 archetype, tier and ownership rules', () {
      final r = lint(
        'feature/library/library_x/mcgen.yaml',
        _feature.replaceFirst(
              'archetype: stub_feature',
              'archetype: utility_hello',
            ) +
            'owned: [lib/x.dart]\n',
      );
      expect(lines(r.err), [
        'feature/library/library_x/mcgen.yaml:3:7: error [archetype] tier: archetype "utility_hello" is for utility modules, not feature',
        'feature/library/library_x/mcgen.yaml:6:8: error [ownership] owned: "owned" files only exist in mixed modules; this one is managed',
      ]);
      final wrongDir = lint('utility/mc_other/mcgen.yaml', helloSpec);
      expect(lines(wrongDir.err), [
        'utility/mc_other/mcgen.yaml:5:9: error [name-collision] module: module "mc_hello" must live in a directory of the same name, not "mc_other"',
      ]);
    });

    test('T-0065-AC4 spec lint --all lints every spec under the root', () {
      final root = tempRoot('lint-all');
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'utility/mc_hello/mcgen.yaml', helloSpec);
      writeFile(
        root,
        'utility/mc_two/mcgen.yaml',
        helloSpec.replaceFirst('module: mc_hello', 'module: mc_hello'),
      );
      final r = mcgen(['spec', 'lint', '--root', root.path, '--all']);
      expect(r.code, 1);
      expect(lines(r.err), [
        'utility/mc_hello/mcgen.yaml:5:9: error [name-collision] module: module "mc_hello" is also specified by utility/mc_two/mcgen.yaml',
        'utility/mc_two/mcgen.yaml:5:9: error [name-collision] module: module "mc_hello" is also specified by utility/mc_hello/mcgen.yaml',
        'utility/mc_two/mcgen.yaml:5:9: error [name-collision] module: module "mc_hello" must live in a directory of the same name, not "mc_two"',
      ]);
      expect(lines(r.out), ['mcgen spec lint: 2 spec(s), 3 error(s)']);
      expect(
        File(p.join(root.path, 'utility/mc_hello/pubspec.yaml')).existsSync(),
        isFalse,
      );
    });
  });
}
