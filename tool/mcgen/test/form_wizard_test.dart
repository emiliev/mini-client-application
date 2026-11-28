// T-0075: the form/wizard archetype (P2-06). Its two exemplars, the
// three-step feature/library/library_reading_list_editor and the one-form
// feature/auth/auth_signin, are its golden: each render must equal its
// exemplar outside owned files (plan 02 KD1, ADR-0017). Two throwaway specs
// (a three-step wizard and a one-step form) prove the templates are not the
// exemplars with names swapped (tool/T-0075-AC3_fw_probe.sh runs them under
// Bazel too).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _wizard = 'feature/library/library_reading_list_editor';
const _form = 'feature/auth/auth_signin';
const _both = [_wizard, _form];

String _name(String rel) => p.basename(rel);

void _copyUtilities(Directory root) {
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
}

/// A temp root holding a copy of the exemplar [rel] and every utility
/// pubspec, with [edit] applied to the spec.
Directory _copyRoot(String rel, String tag, {String Function(String)? edit}) {
  final root = tempRoot(tag);
  _copyUtilities(root);
  final source = p.join(repoRoot, rel);
  for (final f in listTree(source)) {
    final out = File(p.join(root.path, rel, f));
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(File(p.join(source, f)).readAsBytesSync());
  }
  if (edit != null) {
    final spec = File(p.join(root.path, rel, 'mcgen.yaml'));
    final before = spec.readAsStringSync();
    final after = edit(before);
    expect(after, isNot(before), reason: 'the edit changed the spec');
    spec.writeAsStringSync(after);
  }
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

GeneratedModule _render(String root, String specRel) => _generator.generate(
  loadSpec(
    text: File(p.join(root, specRel)).readAsStringSync(),
    file: specRel,
    schema: schema,
  ),
  index: RepoIndex.scan(root),
  forbidden: [root, mcgenDir],
);

const _probes = ['zz_fw_probe', 'zz_fw_plain'];

String _probeRel(String name) => 'feature/zz_probe/$name';

/// A probe spec in a temp root at feature/zz_probe/<name>.
Directory _probeRoot(
  String name,
  String tag, {
  String Function(String)? edit,
}) {
  final root = tempRoot(tag);
  _copyUtilities(root);
  final spec = readFixture('$name/mcgen.yaml');
  writeFile(
    root,
    '${_probeRel(name)}/mcgen.yaml',
    edit == null ? spec : edit(spec),
  );
  return root;
}

/// The lint errors of a probe edited by [edit], from `error` on.
List<String> _lintWith(String name, String Function(String) edit) {
  final root = _probeRoot(name, 'fw-lint', edit: edit);
  addTearDown(() => root.deleteSync(recursive: true));
  final r = mcgen(['spec', 'lint', '--root', root.path, name]);
  expect(r.code, 1, reason: '$r');
  return [
    for (final l in r.err.trim().split('\n')) l.substring(l.indexOf('error')),
  ];
}

void main() {
  group('T-0075-AC1 the exemplars round-trip', () {
    for (final rel in _both) {
      final name = _name(rel);
      test(
        'T-0075-AC1 mcgen gen $name --check exits 0 against the exemplar',
        () {
          final r = mcgen(['gen', '--check', name], cwd: repoRoot);
          expect(r.code, 0, reason: '$r');
          expect(r.out, contains('$rel: up to date'));
          final c = mcgen(['check', name], cwd: repoRoot);
          expect(c.code, 0, reason: '$c');
        },
      );

      test('T-0075-AC1 the round-trip golden of $name: compareToExemplar '
          'finds the render identical to the real exemplar', () {
        final gen = _render(repoRoot, '$rel/mcgen.yaml');
        final diff = compareToExemplar(gen, p.join(repoRoot, rel));
        expect(diff.identical, isTrue, reason: '$diff');
        for (final f in gen.files.values) {
          expect(f.ownership, 'managed', reason: f.path);
        }
        for (final f in [
          'lib/$name.dart',
          'lib/src/di/di_initializer.dart',
          'lib/src/di/flow_scope.dart',
          'lib/src/l10n/${name}_de.arb',
          'pubspec.yaml',
          'test/architecture/architecture_test.dart',
        ]) {
          expect(gen.files.keys, contains(f));
        }
      });
    }

    test('T-0075-AC1 a changed spec field makes --check exit 1 and name the '
        'file', () {
      final wizard = _copyRoot(
        _wizard,
        'field-wizard',
        edit: (s) =>
            s.replaceFirst('pure_files_over: 12', 'pure_files_over: 13'),
      );
      final form = _copyRoot(
        _form,
        'field-form',
        edit: (s) => s.replaceFirst('Anmelden', 'Einloggen'),
      );
      addTearDown(() {
        wizard.deleteSync(recursive: true);
        form.deleteSync(recursive: true);
      });
      final a = mcgen([
        'gen',
        '--check',
        '--root',
        wizard.path,
        'library_reading_list_editor',
      ]);
      expect(a.code, 1, reason: '$a');
      expect(
        a.err,
        contains(
          '$_wizard/test/architecture/architecture_test.dart: round-trip: line',
        ),
      );
      expect(RegExp('round-trip').allMatches(a.err), hasLength(1));
      final b = mcgen(['gen', '--check', '--root', form.path, 'auth_signin']);
      expect(b.code, 1, reason: '$b');
      expect(
        b.err,
        contains('$_form/lib/src/l10n/auth_signin_de.arb: round-trip'),
      );
    });

    test('T-0075-AC1 a flow argument renamed in the spec changes the flow, '
        'and --check names it', () {
      final root = _copyRoot(
        _wizard,
        'arg',
        edit: (s) => s.replaceFirst(
          'state: "ReadingListEditorFlowState(editing: editing)"',
          'state: "ReadingListEditorFlowState(editing: null)"',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'library_reading_list_editor',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(r.err, contains('reading_list_editor_flow.dart: round-trip'));
    });

    test('T-0075-AC1 gen writes only the manifest into an exemplar, and the '
        'committed manifest is the one it writes', () {
      for (final rel in _both) {
        final name = _name(rel);
        final root = _copyRoot(rel, 'manifest-$name');
        addTearDown(() => root.deleteSync(recursive: true));
        final dir = p.join(root.path, rel);
        final before = hashTree(dir);
        final r = mcgen(['gen', '--root', root.path, name]);
        expect(r.code, 0, reason: '$r');
        expect(hashTree(dir), before, reason: 'the committed manifest is it');
      }
    });
  });

  group('T-0075-AC2 the exemplars are unchanged in behaviour', () {
    test(
      'T-0075-AC2 an exemplar renders only the managed layer: the bloc, '
      'the pages, the form, the domain, the steps and BUILD stay its own',
      () {
        for (final rel in _both) {
          final gen = _render(repoRoot, '$rel/mcgen.yaml');
          for (final path in gen.files.keys) {
            expect(path, isNot(startsWith('lib/src/presentation/')));
            expect(path, isNot(startsWith('lib/src/domain/')));
            expect(path, isNot(startsWith('test/feature/step/')));
            expect(path, isNot(startsWith('test/feature/util/')));
            expect(path, isNot('BUILD.bazel'));
          }
        }
      },
    );

    test('T-0075-AC2 the exemplars have no keep region: nothing of a form or '
        'wizard needed one', () {
      for (final rel in _both) {
        final spec = File(p.join(repoRoot, rel, 'mcgen.yaml'))
            .readAsStringSync();
        expect(spec, isNot(contains('\nkeep:')));
        for (final f in listTree(p.join(repoRoot, rel))) {
          if (!f.endsWith('.dart')) continue;
          expect(
            File(p.join(repoRoot, rel, f)).readAsStringSync(),
            isNot(contains('mcgen:keep')),
            reason: f,
          );
        }
      }
    });
  });

  group('T-0075-AC3 throwaway probes', () {
    test('T-0075-AC3 both probe specs lint clean and render the same bytes in '
        'two roots', () {
      for (final name in _probes) {
        final a = _probeRoot(name, 'probe-a');
        final b = _probeRoot(name, 'probe-b');
        addTearDown(() {
          a.deleteSync(recursive: true);
          b.deleteSync(recursive: true);
        });
        final l = mcgen(['spec', 'lint', '--root', a.path, name]);
        expect(l.code, 0, reason: '$l');
        final x = _render(a.path, '${_probeRel(name)}/mcgen.yaml');
        final y = _render(b.path, '${_probeRel(name)}/mcgen.yaml');
        expect(x.files.keys.toList(), y.files.keys.toList());
        for (final k in x.files.keys) {
          expect(x.files[k]!.content, y.files[k]!.content, reason: k);
        }
      }
    });

    test('T-0075-AC3 the probes are their own modules, not an exemplar with '
        'names swapped', () {
      for (final name in _probes) {
        final root = _probeRoot(name, 'probe-own');
        addTearDown(() => root.deleteSync(recursive: true));
        final gen = _render(root.path, '${_probeRel(name)}/mcgen.yaml');
        for (final f in gen.files.values) {
          expect(
            f.content.toLowerCase(),
            isNot(contains('reading')),
            reason: f.path,
          );
          expect(f.content, isNot(contains('SignIn')), reason: f.path);
        }
      }
      final wizard = _render(
        (_probeRoot('zz_fw_probe', 'probe-w')..let(addTearDown)).path,
        '${_probeRel('zz_fw_probe')}/mcgen.yaml',
      );
      final plain = _render(
        (_probeRoot('zz_fw_plain', 'probe-p')..let(addTearDown)).path,
        '${_probeRel('zz_fw_plain')}/mcgen.yaml',
      );
      // Three step pages and a review, against one page and no review.
      final wizardFlow =
          wizard.files['lib/src/flow/zz_fw_probe_flow.dart']!.content;
      final plainFlow =
          plain.files['lib/src/flow/zz_fw_plain_flow.dart']!.content;
      expect(RegExp('McFlowPage').allMatches(wizardFlow), hasLength(3));
      expect(RegExp('McFlowPage').allMatches(plainFlow), hasLength(1));
      expect(
        wizard
            .files['lib/src/presentation/page/zz_fw_probe_step_page.dart']!
            .content,
        contains('failureMessage(failure, core)'),
      );
      expect(
        plain
            .files['lib/src/presentation/page/zz_fw_plain_step_page.dart']!
            .content,
        contains('failureMessage(failure, core)'),
      );
    });

    test('T-0075-AC3 the template covers every behaviour the task names', () {
      final root = _probeRoot('zz_fw_probe', 'probe-behaviour');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '${_probeRel('zz_fw_probe')}/mcgen.yaml');
      final bloc =
          gen.files['lib/src/presentation/bloc/zz_fw_probe_bloc.dart']!.content;
      // The session-epoch rule, the closed guard and the one-save guard.
      expect(bloc, contains('_session.epoch != _epoch'));
      expect(bloc, contains('isClosed'));
      expect(bloc, contains('wizard.complete()'));
      // A server code is mapped to its field and step (`reject`).
      expect(bloc, contains('wizard.reject(field, serverError(code))'));
      // Writes are pinned with authPinned.
      expect(
        gen
            .files['lib/src/domain/repository/zz_fw_probe_repository.dart']!
            .content,
        contains('authPinned(epoch)'),
      );
      // Validators from mc_forms, per field.
      final form =
          gen.files['lib/src/presentation/form/zz_fw_probe_form.dart']!.content;
      expect(form, contains('Validators.required<String>()'));
      expect(form, contains('Validators.maxLength(60)'));
      expect(form, contains('Validators.maxLength(280)'));
      // The flow result type.
      expect(
        gen.files['lib/src/flow/zz_fw_probe_flow.dart']!.content,
        contains('ValueChanged<ShelfId?> onComplete'),
      );
    });

    test('T-0075-AC3 the skeleton files are owned and the managed layer is '
        'not', () {
      final root = _probeRoot('zz_fw_probe', 'probe-owned');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '${_probeRel('zz_fw_probe')}/mcgen.yaml');
      for (final f in [
        'BUILD.bazel',
        'lib/src/domain/repository/zz_fw_probe_repository.dart',
        'lib/src/presentation/bloc/zz_fw_probe_bloc.dart',
        'lib/src/presentation/form/zz_fw_probe_form.dart',
        'lib/src/presentation/page/zz_fw_probe_step_page.dart',
        'test/feature/util/zz_fw_probe_env.dart',
        'test/flow_scope_test.dart',
      ]) {
        expect(gen.files[f]?.ownership, 'owned', reason: f);
      }
      for (final f in [
        'lib/zz_fw_probe.dart',
        'lib/src/flow/zz_fw_probe_flow.dart',
        'lib/src/flow/zz_fw_probe_flow_state.dart',
        'test/architecture/architecture_test.dart',
      ]) {
        expect(gen.files[f]?.ownership, 'managed', reason: f);
      }
    });

    test('T-0075-AC3 a step no template knows is written once, as a failing '
        'stub', () {
      final root = _probeRoot(
        'zz_fw_probe',
        'probe-stub',
        edit: (s) => s.replaceFirst(
          '          - "And I am on step {1}"\n',
          '          - "And I am on step {1}"\n'
              '          - And the shelf holds {3} boxes of {\'tea\'}\n',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '${_probeRel('zz_fw_probe')}/mcgen.yaml');
      final stub =
          gen.files['test/feature/step/the_shelf_holds_boxes_of.dart']!;
      expect(stub.ownership, 'owned');
      expect(
        stub.content,
        contains("fail('step \"theShelfHoldsBoxesOf\" is not written yet');"),
      );
    });

    test('T-0075-AC3 a prose slot no template uses fails gen, naming it', () {
      final root = _probeRoot(
        'zz_fw_probe',
        'probe-prose',
        edit: (s) => s.replaceFirst(
          'options:\n',
          'options:\n  prose:\n    flow.dco: A typo.\n',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen(['gen', '--check', '--root', root.path, 'zz_fw_probe']);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('options.prose has slot(s) no template uses: flow.dco'),
      );
    });

    test('T-0075-AC3 a missing de string is a lint error, not pseudo text', () {
      final errors = _lintWith(
        'zz_fw_probe',
        (s) => s.replaceFirst(
          'text: {en: New shelf, de: Neues Regal}',
          'text: {en: New shelf}',
        ),
      );
      expect(errors, hasLength(1));
      expect(errors.single, contains('"zzFwProbeTitle" has no "de" text'));
    });
  });

  group(
    'T-0075-AC3 lint rejects a spec the emitters would fail on, per role',
    () {
      test('T-0075-AC3 unknown and missing options', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst('options:\n', 'options:\n  colour: red\n'),
          ),
          ['error [form_wizard] options.colour: unknown key "colour"'],
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst('  pascal: ZzFwProbe\n', ''),
          ),
          ['error [form_wizard] options.pascal: "pascal" must be a string'],
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) =>
                s.replaceFirst('  arb: block_placeholders\n', '  arb: wide\n'),
          ),
          [
            'error [form_wizard] options.arb: "arb" must be inline or block_placeholders, not "wide"',
          ],
        );
      });

      test('T-0075-AC3 types: every type a template writes is declared, with a '
          'file', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              'type: ShelfId?\n      cast: result as ShelfId?',
              'type: ShelfId?\n      cast: result as Wobble?',
            ),
          ),
          [
            'error [form_wizard] options.flow.result.cast: type "Wobble" is not in options.types',
          ],
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '    ShelfId: domain/model/shelf_id.dart\n',
              '    ShelfId: domain/model/shelf_id\n',
            ),
          ),
          contains(
            'error [form_wizard] options.types.ShelfId: must be a .dart file',
          ),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '  barrel: [ShelfId]',
              '  barrel: [ShelfId, Nope]',
            ),
          ),
          [
            'error [form_wizard] options.barrel: barrel type "Nope" is not in options.types',
          ],
        );
      });

      test('T-0075-AC3 root imports and the flow: roles the flow and the flow '
          'scope read', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              'root_imports: [Dio, Monitoring, SessionReader]',
              'root_imports: [Dio, Monitoring, SessionReader, Ghost]',
            ),
          ),
          [
            'error [form_wizard] options.root_imports: root import "Ghost" is not in options.types',
          ],
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              'state: const ZzFwProbeFlowState()',
              'state: const Other()',
            ),
          ),
          contains(
            'error [form_wizard] options.flow.state: must construct ZzFwProbeFlowState, not "const Other()"',
          ),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s
                .replaceFirst('        when: "state.step >= 1"\n', '')
                .replaceFirst('      - name: notes', '      - name: details'),
          ),
          contains(
            'error [form_wizard] options.flow.pages[1].name: page "details" twice',
          ),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '      - name: details\n',
              '      - name: details\n        when: "true"\n',
            ),
          ),
          contains(
            'error [form_wizard] options.flow.pages[0].when: the first page is the flow root and has no condition',
          ),
        );
      });

      test('T-0075-AC3 flow arguments and the flow state', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '    result:\n      type: ShelfId?',
              '    args:\n      - {name: shelf, type: Wobble?}\n    result:\n      type: ShelfId?',
            ),
          ),
          containsAll([
            'error [form_wizard] options.flow.args[0].type: type "Wobble" is not in options.types (give its file under lib/src/ or its package: URI)',
          ]),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '        type: int\n        default: "0"',
              '        type: Wobble\n        default: "0"',
            ),
          ),
          contains(
            'error [form_wizard] options.flow_state.fields[0].type: type "Wobble" is not in options.types (give its file under lib/src/ or its package: URI)',
          ),
        );
      });

      test(
        'T-0075-AC3 the skeleton: steps, fields, strings, the result and the '
        'page',
        () {
          List<String> lint(String from, String to) =>
              _lintWith('zz_fw_probe', (s) => s.replaceFirst(from, to));
          expect(
            lint('      - id: review\n', ''),
            contains(
              'error [form_wizard] options.skeleton.steps: a wizard of several steps ends with a review step (no fields)',
            ),
          );
          expect(
            lint('    noun: shelf\n', '    noun: Shelf Case\n'),
            contains(
              'error [form_wizard] options.skeleton.noun: the noun is lower-case words',
            ),
          );
          expect(
            lint('      file: shelf_id.dart\n', '      file: other_id.dart\n'),
            contains(
              'error [form_wizard] options.types.ShelfId: a skeleton writes the result at domain/model/other_id.dart',
            ),
          );
          expect(
            lint(
              '    ZzFwProbeStepPage: presentation/page/zz_fw_probe_step_page.dart\n',
              '    ZzFwProbeStepPage: presentation/page/x.dart\n',
            ),
            contains(
              'error [form_wizard] options.types.ZzFwProbeStepPage: a skeleton writes the step page at presentation/page/zz_fw_probe_step_page.dart',
            ),
          );
          expect(
            lint(
              '    - key: zzFwProbeNameLabel\n',
              '    - key: zzFwProbeNameLabelX\n',
            ),
            contains(
              'error [form_wizard] l10n.strings: form_wizard needs the string "zzFwProbeNameLabel"',
            ),
          );
          expect(
            lint(
              'root_imports: [Dio, Monitoring, SessionReader]',
              'root_imports: [Monitoring, SessionReader]',
            ),
            contains(
              'error [form_wizard] options.root_imports: a skeleton sends its request through Dio, reads the session and reports to monitoring: root_imports needs "Dio"',
            ),
          );
          expect(
            lint(
              '          - {name: name, label: Name, required: true, max: 60, trim: true}',
              '          - {name: name, label: Name, required: true, max: 60, trim: true}\n          - {name: name, label: Again}',
            ),
            contains(
              'error [form_wizard] options.skeleton.steps: field "name" twice',
            ),
          );
          expect(
            lint(
              '    fixtures: [identity.default, library.default]',
              '    fixtures: [identity]',
            ),
            contains(
              'error [form_wizard] options.skeleton.fixtures: "identity" is not <package>.<set>',
            ),
          );
          expect(
            lint(
              '        widget: "ZzFwProbeStepPage(step: 1)"',
              '        widget: "ZzFwProbeStepPage(step: 2)"',
            ),
            contains(
              'error [form_wizard] options.flow.pages[1].widget: a skeleton page is "ZzFwProbeStepPage(step: 1)", not "ZzFwProbeStepPage(step: 2)"',
            ),
          );
          expect(
            lint('  barrel: [ShelfId]', '  barrel: []'),
            contains(
              'error [form_wizard] options.barrel: the barrel exports the result "ShelfId"',
            ),
          );
        },
      );

      test('T-0075-AC3 a one-step form page shows the saving and the failure '
          'state, as a review does', () {
        final root = _probeRoot('zz_fw_plain', 'probe-onestep');
        addTearDown(() => root.deleteSync(recursive: true));
        final gen = _render(
          root.path,
          '${_probeRel('zz_fw_plain')}/mcgen.yaml',
        );
        final page = gen
            .files['lib/src/presentation/page/zz_fw_plain_step_page.dart']!
            .content;
        expect(page, contains('if (wizard.isCompleting)'));
        expect(page, contains('Text(failureMessage(failure, core)'));
        expect(page, contains('key: saveErrorKey'));
        expect(
          readFixture('zz_fw_plain/mcgen.yaml'),
          contains('A failing backend shows the failure on the form'),
        );
      });

      test('T-0075-AC3 placeholders are checked: Step takes two ints, TooLong '
          'one, every other key none', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              'placeholders: {step: {type: int}, total: {type: int}}\n',
              'placeholders: {step: {type: int}}\n',
            ),
          ),
          contains(
            'error [form_wizard] l10n.strings[1].placeholders: '
            '"zzFwProbeStep" needs the int placeholders step, total',
          ),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              'placeholders: {max: {type: int}}\n'
                  '      text: {en: "Use at most {max} characters.", '
                  'de: "Verwende höchstens {max} Zeichen."}\n'
                  '    - key: zzFwProbeNameRefused',
              'placeholders: {max: {type: String}}\n'
                  '      text: {en: "Use at most {max} characters.", '
                  'de: "Verwende höchstens {max} Zeichen."}\n'
                  '    - key: zzFwProbeNameRefused',
            ),
          ),
          contains(
            'error [form_wizard] l10n.strings[11].placeholders: '
            '"zzFwProbeNameTooLong" needs the int placeholders max',
          ),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '      description: The Back button.\n',
              '      description: The Back button.\n'
                  '      placeholders: {x: {type: int}}\n',
            ),
          ),
          contains(
            'error [form_wizard] l10n.strings[2].placeholders: '
            '"zzFwProbeBack" needs no placeholders',
          ),
        );
      });

      test('T-0075-AC3 a required flow-state field the state expression does '
          'not set is a lint error', () {
        expect(
          _lintWith(
            'zz_fw_plain',
            (s) => s.replaceFirst('        default: "0"\n', ''),
          ),
          contains(
            'error [form_wizard] options.flow.state: the flow state requires '
            '"step" (not nullable, no default), but the state expression '
            'does not set it',
          ),
        );
      });

      test('T-0075-AC3 names in the widget, the condition and the key are '
          'checked and imported', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s
                .replaceFirst(
                  'widget: "ZzFwProbeStepPage(step: 0)"',
                  'widget: "ZzFwProbeStepPage(step: 0, g: Ghost())"',
                )
                .replaceFirst(
                  '"state.step >= 1"',
                  '"state.step >= Phantom.one"',
                ),
          ),
          containsAll([
            'error [form_wizard] options.flow.pages[0].widget: '
                'type "Ghost" is not in options.types',
            'error [form_wizard] options.flow.pages[1].when: '
                'type "Phantom" is not in options.types',
          ]),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst('  flow:\n', '  flow:\n    key: Wraith.id\n'),
          ),
          contains(
            'error [form_wizard] options.flow.key: '
            'type "Wraith" is not in options.types',
          ),
        );
        final root = _copyRoot(
          _wizard,
          'refs',
          edit: (s) => s
              .replaceFirst(
                '    ReadingListId: domain/model/reading_list_id.dart\n',
                '    ReadingListId: domain/model/reading_list_id.dart\n'
                    '    Limits: domain/model/limits.dart\n',
              )
              .replaceFirst('"state.step >= 1"', '"state.step >= Limits.one"'),
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final gen = _render(root.path, '$_wizard/mcgen.yaml');
        expect(
          gen.files['lib/src/flow/reading_list_editor_flow.dart']!.content,
          contains(
            "import 'package:library_reading_list_editor/src/domain/model/"
            "limits.dart';",
          ),
        );
      });

      test('T-0075-AC3 spec text written into a Dart literal is escaped: a '
          r'quote, a backslash and a $', () {
        final root = _probeRoot(
          'zz_fw_probe',
          'probe-escape',
          edit: (s) => s
              .replaceFirst(
                '{name: name, label: Name,',
                r'''{name: name, label: "Author's $name\\",''',
              )
              .replaceFirst('path: v1/me/lists', r'''path: "v1/it's/$x"'''),
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final gen = _render(
          root.path,
          '${_probeRel('zz_fw_probe')}/mcgen.yaml',
        );
        expect(
          gen.files['test/flow_scope_test.dart']!.content,
          contains(r"('Author\'s \$name\\', 'x')"),
        );
        expect(
          gen
              .files['lib/src/domain/repository/zz_fw_probe_repository.dart']!
              .content,
          contains(r"'v1/it\'s/\$x'"),
        );
      });

      test('T-0075-AC3 a request body key written twice is a lint error', () {
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) => s.replaceFirst(
              '        comicIds: "const <int>[]"\n',
              '        comicIds: "const <int>[]"\n        name: "1"\n',
            ),
          ),
          contains(
            'error [form_wizard] options.skeleton.submit: request body key '
            '"name" is written twice (fields and submit.extra)',
          ),
        );
      });

      test('T-0075-AC3 a flow argument is matched by word, and a bad name is '
          'reported at its own path', () {
        final args = _copyRoot(
          _wizard,
          'arg-word',
          edit: (s) => s.replaceFirst(
            '    result:\n      type: ReadingListId?',
            '      - {name: edit, type: String?}\n'
                '    result:\n      type: ReadingListId?',
          ),
        );
        addTearDown(() => args.deleteSync(recursive: true));
        final r = mcgen([
          'spec',
          'lint',
          '--root',
          args.path,
          'library_reading_list_editor',
        ]);
        expect(r.code, 1, reason: '$r');
        expect(
          r.err,
          contains(
            'flow argument "edit" is used by neither options.flow.state '
            'nor options.flow.key',
          ),
        );
        expect(
          _lintWith(
            'zz_fw_probe',
            (s) =>
                s.replaceFirst('      - name: step\n', '      - name: Step\n'),
          ),
          contains(
            'error [form_wizard] options.flow_state.fields[0].name: '
            '"Step" is not a Dart name',
          ),
        );
      });

      test(
        'T-0075-AC3 an archetype error prints the spec path and the message, '
        'and gen prints no stack',
        () {
          final root = _probeRoot(
            'zz_fw_probe',
            'probe-error',
            edit: (s) => s.replaceFirst(
              'state: const ZzFwProbeFlowState()',
              'state: const Other()',
            ),
          );
          addTearDown(() => root.deleteSync(recursive: true));
          final r = mcgen(['gen', '--root', root.path, 'zz_fw_probe']);
          expect(r.code, 1, reason: '$r');
          expect(r.err, contains('feature/zz_probe/zz_fw_probe/mcgen.yaml:'));
          expect(r.err, contains('options.flow.state'));
          expect(r.err, isNot(contains('#0 ')));
        },
      );
    },
  );

  group('T-0075-AC4 the shared code is untouched', () {
    test('T-0075-AC4 every existing exemplar still round-trips', () {
      for (final name in [
        'characters_list',
        'discovery_search',
        'characters_search',
        'comics_details',
        'characters_details',
      ]) {
        final r = mcgen(['gen', '--check', name], cwd: repoRoot);
        expect(r.code, 0, reason: '$name: $r');
      }
    });

    test('T-0075-AC4 form_wizard is registered, and only for features', () {
      expect(archetypes.keys, contains('form_wizard'));
      expect(archetypes['form_wizard']!.tiers, {Tier.feature});
    });
  });
}

extension on Directory {
  void let(void Function(void Function()) addTearDown) =>
      addTearDown(() => deleteSync(recursive: true));
}
