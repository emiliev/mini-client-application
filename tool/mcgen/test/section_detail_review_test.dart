// T-0072 review round: what a batch of section_detail specs hits. Specs that
// pass lint but generated wrong or non-compiling code: the favourites path,
// no hand-over, ids that are not int, a two-word item, a missing open string,
// missing entities, nested DTOs in the mapper, and Examples tables.
// tool/T-0072-AC3_sc_probe.sh builds the same specs under Bazel.

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

String _specOf(String fixture) => 'feature/zz_probe/$fixture/mcgen.yaml';

Directory _root(
  String tag, {
  String fixture = 'zz_sc_probe',
  String Function(String)? edit,
}) {
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
  final text = readFixture('$fixture/mcgen.yaml');
  writeFile(root, _specOf(fixture), edit == null ? text : edit(text));
  return root;
}

Map<String, String> _render(Directory root, String fixture) {
  final tool = ToolLayout(mcgenDir);
  final cfg = tool.loadConfig();
  final gen = Generator(
    config: cfg,
    archetypes: archetypes,
    bricks: BrickSet(tool.bricksDir),
    formatter: DartFormatter(cfg),
  );
  final spec = _specOf(fixture);
  final m = gen.generate(
    loadSpec(
      text: File(p.join(root.path, spec)).readAsStringSync(),
      file: spec,
      schema: SpecSchema.load(p.join(mcgenDir, 'schema', 'mcgen-1.json')),
    ),
    index: RepoIndex.scan(root.path),
    forbidden: [root.path, mcgenDir],
  );
  return {for (final f in m.files.values) f.path: f.content};
}

List<String> _lint(Directory root, String module) {
  final r = mcgen(['spec', 'lint', '--root', root.path, module]);
  expect(r.code, 1, reason: '$r');
  return [
    for (final l in r.err.trim().split('\n')) l.substring(l.indexOf('error')),
  ];
}

void main() {
  test('T-0072-AC3 the default favourites path comes from the kind, and the '
      'probe and the API use the same path', () {
    // Item "issue", kind "comic", no path given: the kind names the path.
    final byKind = _root(
      'kind',
      edit: (s) =>
          s.replaceFirst('  favourite_path: v1/me/favourites/comic/{id}\n', ''),
    );
    final a = _render(byKind, 'zz_sc_probe');
    expect(
      a['lib/src/domain/api/zz_sc_probe_api.dart'],
      contains("@GET('v1/me/favourites/comic/{id}')"),
    );
    expect(
      a['test/feature/util/favourites_probe.dart'],
      contains("'/v1/me/favourites/comic/\$issue'"),
    );
    // A custom path wins, in both.
    final custom = _root(
      'path',
      edit: (s) => s.replaceFirst(
        'favourite_path: v1/me/favourites/comic/{id}',
        'favourite_path: v1/me/likes/{id}/flag',
      ),
    );
    final b = _render(custom, 'zz_sc_probe');
    expect(
      b['lib/src/domain/api/zz_sc_probe_api.dart'],
      contains("@PUT('v1/me/likes/{id}/flag')"),
    );
    expect(
      b['test/feature/util/favourites_probe.dart'],
      contains("'/v1/me/likes/\$issue/flag'"),
    );
    // The two-word story arc has kind "comic" too and no path: same rule.
    final story = _render(
      _root('kind2', fixture: 'zz_sc_story'),
      'zz_sc_story',
    );
    expect(
      story['lib/src/domain/api/zz_sc_story_api.dart'],
      contains("@GET('v1/me/favourites/comic/{id}')"),
    );
    expect(
      story['test/feature/util/favourites_probe.dart'],
      contains("'/v1/me/favourites/comic/\$storyArc'"),
    );
  });

  test('T-0072-AC3 a spec with no hand-over has no navigator in its details '
      'bloc, no guard and no timer', () {
    final files = _render(
      _root('plain', fixture: 'zz_sc_plain'),
      'zz_sc_plain',
    );
    final bloc = files['lib/src/presentation/bloc/ticket_details_bloc.dart']!;
    for (final gone in [
      '_navigator',
      'Timer',
      'openGuard',
      '_startOpenGuard',
      'dart:async',
      'Navigator',
      'mcgen:keep',
    ]) {
      expect(bloc, isNot(contains(gone)), reason: gone);
    }
    expect(bloc, contains('_flow.state.ticketId'));
    // The favourite bloc still signs in through the navigator.
    expect(
      files['lib/src/presentation/bloc/ticket_favourite_bloc.dart'],
      contains('_navigator.requestSignIn()'),
    );
  });

  test('T-0072-AC3 a two-word item and String ids: file stems, the freezed '
      'targets and the id types', () {
    final root = _root('story', fixture: 'zz_sc_story');
    final lint = mcgen(['spec', 'lint', '--root', root.path, 'zz_sc_story']);
    expect(lint.code, 0, reason: '$lint');
    final files = _render(root, 'zz_sc_story');
    expect(
      files.keys,
      containsAll([
        'lib/src/presentation/bloc/story_arc_details_bloc.dart',
        'lib/src/presentation/bloc/story_arc_details_event.dart',
        'lib/src/presentation/bloc/story_arc_details_state.dart',
        'lib/src/presentation/bloc/story_arc_favourite_bloc.dart',
        'lib/src/presentation/page/story_arc_details_page.dart',
        'test/feature/step/i_open_story_arc.dart',
      ]),
    );
    // The freezed targets: `mcgen buildgen` writes the BUILD file since
    // T-0074 and names a new module's targets after their files.
    final dir = p.dirname(_specOf('zz_sc_story'));
    for (final e in files.entries) {
      writeFile(root, '$dir/${e.key}', e.value);
    }
    final bg = mcgen(['buildgen', '--root', root.path, p.join(root.path, dir)]);
    expect(bg.code, 0, reason: '$bg');
    final build = readFile(root, '$dir/BUILD.bazel');
    expect(
      build,
      contains(
        '"story_arc_details_bloc": "lib/src/presentation/bloc/story_arc_details_bloc.dart"',
      ),
    );
    expect(
      build,
      contains(
        '"story_arc_favourite_bloc": "lib/src/presentation/bloc/story_arc_favourite_bloc.dart"',
      ),
    );
    expect(build, contains('":_story_arc_details_bloc_freezed"'));
    final bloc =
        files['lib/src/presentation/bloc/story_arc_details_bloc.dart']!;
    expect(bloc, contains("part 'story_arc_details_bloc.freezed.dart';"));
    // Ids: the API, the guard record, the steps and the env use String.
    final api = files['lib/src/domain/api/zz_sc_story_api.dart']!;
    expect(api, contains("getStoryArc(@Path('id') String id)"));
    expect(api, contains("getFavourite(@Path('id') String id)"));
    expect(bloc, contains('(String, String)? _openTarget'));
    expect(
      files['test/feature/step/i_open_story_arc.dart'],
      contains('iOpenStoryArc(WidgetTester tester, String id)'),
    );
    expect(
      files['test/feature/util/favourites_probe.dart'],
      contains('String storyArc,'),
    );
    expect(
      files['test/feature/util/zz_sc_story_env.dart'],
      contains('zzScStoryFlowUnderTest(String id)'),
    );
  });

  test('T-0072-AC3 the mapper converts nested DTOs, lists and nullable ids', () {
    final mapper = _render(
      _root('mapper', fixture: 'zz_sc_story'),
      'zz_sc_story',
    )['lib/src/domain/model/story_arc_mapper.dart']!;
    expect(mapper, contains('id: StoryArcId(id)'));
    expect(
      mapper,
      contains('parent: parent == null ? null : StoryArcId(parent!)'),
    );
    expect(
      mapper,
      contains('chapters: [for (final e in chapters) e.toDomain()]'),
    );
    expect(mapper, contains('owner: owner.toDomain()'));
    expect(
      mapper,
      contains(
        'notes: notes == null ? null : [for (final e in notes!) e.toDomain()]',
      ),
    );
    expect(mapper, contains('author: PersonId(author)'));
    expect(mapper, contains('extension ChapterDtoMapper on ChapterDto'));
    expect(mapper, contains('extension OwnerDtoMapper on OwnerDto'));
  });

  test('T-0072-AC3 an open with a field needs its Open<Label> string', () {
    final root = _root(
      'open-string',
      edit: (s) => s.replaceFirst(
        '    - key: zzScProbeOpenSeries\n'
            "      description: Button that opens the issue's series.\n"
            '      text: {en: Open series, de: Serie öffnen}\n',
        '',
      ),
    );
    expect(_lint(root, 'zz_sc_probe'), [
      'error [section_detail] l10n.strings: section_detail needs the string "zzScProbeOpenSeries"',
    ]);
  });

  test('T-0072-AC3 lint reports a missing entity, a DTO that is not one and a '
      'missing related entity, each as a diagnostic', () {
    List<String> lintWith(String Function(String) edit) =>
        _lint(_root('ent', edit: edit), 'zz_sc_probe');
    expect(
      lintWith((s) => s.replaceFirst('entity: Issue\n', 'entity: Gadget\n')),
      ['error [section_detail] options.entity: no entity "Gadget" in entities'],
    );
    expect(
      lintWith((s) => s.replaceFirst('dto: IssueDto\n', 'dto: Issue\n')),
      [
        'error [section_detail] options.dto: "Issue" must be a DTO: add `json: true`',
      ],
    );
    expect(
      lintWith(
        (s) => s.replaceFirst(
          'options:\n',
          'options:\n  related: {name: parts, item: part, summary: Nope, '
              'page_dto: NopePage, path: v1/x, param: id, limit: 3}\n',
        ),
      ),
      [
        'error [section_detail] options.related.summary: no entity "Nope" in entities',
        'error [section_detail] options.related.page_dto: no entity "NopePage" in entities',
      ],
    );
  });

  test('T-0072-AC4 an Examples cell is padded to its column; a hand-padded '
      'one is kept only when it is wider', () {
    final root = _root(
      'table',
      edit: (s) => s.replaceFirst(
        '      - id: MC-zz_sc_probe-08\n',
        '      - id: MC-zz_sc_probe-09\n'
            '        title: A table\n'
            '        steps:\n'
            '          - And I see {<a>}\n'
            '        examples:\n'
            '          - [a, "b"]\n'
            '          - ["x", "wide-cell"]\n'
            '          - ["y", "n "]\n'
            '          - ["z", "w   "]\n'
            '      - id: MC-zz_sc_probe-08\n',
      ),
    );
    final feature = _render(
      root,
      'zz_sc_probe',
    )['test/feature/zz_sc_probe.feature']!;
    expect(
      feature,
      contains(
        '      | a | b         |\n'
        '      | x | wide-cell |\n'
        '      | y | n         |\n'
        '      | z | w         |\n',
      ),
    );
  });
}
