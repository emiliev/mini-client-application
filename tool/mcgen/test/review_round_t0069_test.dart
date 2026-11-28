// T-0069's review round: the findings that blocked the merge, each pinned.
//   1. a missing translation is a lint error (never shipped pseudo text),
//      and nothing an archetype throws crashes gen;
//   2. pseudo-translation leaves ICU placeholders and plurals intact;
//   3. rule-driven outlines render (Scenario Outline plus Examples);
//   4. the round-trip skips files git ignores (.DS_Store, .idea/, ...).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:mcgen/src/emit/feature_list_detail/package.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _probe = 'feature/zz_probe/zz_ld_probe';
const _exemplarRel = 'feature/characters/characters_list';

/// The probe spec in a temp root (with every utility pubspec), [edit]ed.
Directory _probeRoot(String tag, {String Function(String)? edit}) {
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
  final spec = readFixture('zz_ld_probe/mcgen.yaml');
  final edited = edit == null ? spec : edit(spec);
  if (edit != null) expect(edited, isNot(spec), reason: 'the edit applied');
  writeFile(root, '$_probe/mcgen.yaml', edited);
  return root;
}

Run _gen(Directory root) =>
    mcgen(['gen', '--check', '--root', root.path, 'zz_ld_probe']);

void main() {
  group('T-0069-AC3 review round 1: missing strings', () {
    test('T-0069-AC3 a missing de string is a lint error, not pseudo text', () {
      final root = _probeRoot(
        'no-de',
        edit: (s) => s.replaceFirst(
          'text: {en: Loading comics, de: Comics werden geladen}',
          'text: {en: Loading comics}',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = _gen(root);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains(
          'error [list_detail] l10n.strings[1].text: "zzLdProbeLoading" has no "de" text',
        ),
      );
      expect(r.err, isNot(contains('Ļóàðíñĝ')), reason: 'no pseudo de');
    });

    test('T-0069-AC3 a missing en string is a diagnostic, not a crash', () {
      final root = _probeRoot(
        'no-en',
        edit: (s) => s.replaceFirst(
          'text: {en: Loading comics, de: Comics werden geladen}',
          'text: {de: Comics werden geladen}',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = _gen(root);
      expect(r.code, 1, reason: '$r');
      expect(r.err, contains('"zzLdProbeLoading" has no "en" text'));
      expect(r.err, isNot(contains('TypeError')));
      expect(r.err, isNot(contains('Null check')));
    });

    test('T-0069-AC3 whatever an archetype throws becomes a diagnostic', () {
      final root = tempRoot('throws');
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'utility/mc_hello/mcgen.yaml', helloSpec);
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runMcgen(
        ['gen', '--check', '--root', root.path, 'mc_hello'],
        out: out,
        err: err,
        archetypes: {'utility_hello': const _Throwing()},
      );
      expect(code, 1);
      expect(
        '$err',
        contains(
          'utility/mc_hello/mcgen.yaml: error [emit] archetype "utility_hello" '
          'failed (_TypeError)',
        ),
      );
    });
  });

  group('T-0069-AC3 review round 2: pseudo-translation and ICU', () {
    test('T-0069-AC3 a placeholder and a plural survive pseudo()', () {
      String tildes(String s) => '~' * (s.length * 2 / 5).ceil();
      expect(pseudo('Hello {name}'), '[Ĥéļļó {name} ~~~~~]');
      const plural =
          '{count, plural, =0{No comics} =1{One {kind}} other{{count} comics}}';
      expect(
        pseudo(plural),
        '[{count, plural, =0{Ñó çóɱíçš} =1{Óñé {kind}} other{{count} çóɱíçš}} '
        '${tildes(plural)}]',
      );
      const select = '{gender, select, female{She} other{They}} left';
      expect(
        pseudo(select),
        '[{gender, select, female{Šĥé} other{Ţĥéý}} ļéfţ ${tildes(select)}]',
      );
    });

    test('T-0069-AC3 the probe\'s en_XA keeps the plural and its placeholders '
        'metadata reaches the template ARB', () {
      final root = _probeRoot('pseudo');
      addTearDown(() => root.deleteSync(recursive: true));
      final out = tempRoot('pseudo-out');
      addTearDown(() => out.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--root',
        root.path,
        '--out',
        out.path,
        'zz_ld_probe',
      ]);
      expect(r.code, 0, reason: '$r');
      final xa = readFile(out, 'lib/src/l10n/zz_ld_probe_en_XA.arb');
      expect(
        xa,
        contains(
          '"zzLdProbeShown": "[{count, plural, =0{Ñó çóɱíçš} =1{Óñé çóɱíç} '
          'other{{count} çóɱíçš}} ',
        ),
      );
      expect(xa, contains('"zzLdProbeGreeting": "[Ĥéļļó {name} ~~~~~]"'));
      final en = readFile(out, 'lib/src/l10n/zz_ld_probe_en.arb');
      expect(
        en,
        contains(
          '"@zzLdProbeShown": {"description": "How many comics the list holds '
          '(not shown yet; checks gen-l10n takes the plural).", '
          '"placeholders": {"count":{"type":"int"}}}',
        ),
      );
      final de = readFile(out, 'lib/src/l10n/zz_ld_probe_de.arb');
      expect(de, isNot(contains('[')), reason: 'de is never pseudo');
    });
  });

  group('T-0069-AC3 review round 3: outlines', () {
    test('T-0069-AC3 a rule-driven outline renders as a Scenario Outline with '
        'the rule\'s examples', () {
      final root = _probeRoot('outline');
      addTearDown(() => root.deleteSync(recursive: true));
      final out = tempRoot('outline-out');
      addTearDown(() => out.deleteSync(recursive: true));
      expect(
        mcgen([
          'gen',
          '--root',
          root.path,
          '--out',
          out.path,
          'zz_ld_probe',
        ]).code,
        0,
      );
      final feature = readFile(out, 'test/feature/zz_ld_probe.feature');
      expect(
        feature,
        endsWith(
          '\n'
          '  @MC-zz_ld_probe-08\n'
          '  Scenario Outline: Tapping a comic previews that comic\n'
          '    When I open the comics list\n'
          '    And I tap {<tap>}\n'
          '    Then I see the comic preview for {<expect>}\n'
          '\n'
          '    Examples:\n'
          "      | tap                   | expect                |\n"
          "      | 'Amber Chronicles #1' | 'Amber Chronicles #1' |\n"
          "      | 'Amber Chronicles #2' | 'Amber Chronicles #2' |\n",
        ),
      );
    });

    test('T-0069-AC3 an outline without steps is a lint error', () {
      final root = _probeRoot(
        'outline-nosteps',
        edit: (s) => s.replaceFirst(
          '        steps:\n'
              '          - When I open the comics list\n'
              '          - And I tap {<tap>}\n'
              '          - Then I see the comic preview for {<expect>}\n',
          '',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = _gen(root);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains(
          'outline "MC-zz_ld_probe-08" needs steps: its Examples are rule "previewTitle"\'s examples',
        ),
      );
    });
  });

  group('T-0069-AC1 review round 4: ignored local files', () {
    test('T-0069-AC1 a .DS_Store, an IDE folder and coverage output do not '
        'fail --check', () {
      final root = tempRoot('ignored');
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
      final exemplar = p.join(repoRoot, _exemplarRel);
      for (final rel in listTree(exemplar)) {
        final f = File(p.join(root.path, _exemplarRel, rel));
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(File(p.join(exemplar, rel)).readAsBytesSync());
      }
      for (final junk in [
        '.DS_Store',
        'lib/src/.DS_Store',
        '.idea/workspace.xml',
        'characters_list.iml',
        'coverage/lcov.info',
      ]) {
        writeFile(root, '$_exemplarRel/$junk', 'local\n');
      }
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_list',
      ]);
      expect(r.code, 0, reason: '$r');

      writeFile(root, '$_exemplarRel/lib/src/stray.dart', 'const x = 1;\n');
      final stray = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_list',
      ]);
      expect(stray.code, 1, reason: 'a file git does not ignore still counts');
      expect(
        stray.err,
        contains(
          '$_exemplarRel/lib/src/stray.dart: round-trip: in the exemplar, but not rendered',
        ),
      );
    });

    test('T-0069-AC1 in a checkout, git check-ignore decides', () {
      final root = tempRoot('git-ignored');
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, '.gitignore', '*.local\n');
      writeFile(root, 'a.dart', '');
      writeFile(root, 'notes.local', '');
      final git = Process.runSync('git', ['init', '-q', root.path]);
      expect(git.exitCode, 0, reason: '${git.stderr}');
      expect(gitIgnored(root.path, ['a.dart', 'notes.local']), {'notes.local'});
      final plain = tempRoot('not-a-checkout');
      addTearDown(() => plain.deleteSync(recursive: true));
      expect(gitIgnored(plain.path, ['notes.local']), isEmpty);
    });
  });
}

/// An archetype with a bug: it throws something that is not a StateError.
class _Throwing extends Archetype {
  const _Throwing();

  @override
  String get name => 'utility_hello';

  @override
  Set<Tier> get tiers => const {Tier.utility};

  @override
  void emit(EmitContext ctx) {
    final Object? missing = ctx.spec.options['missing'];
    ctx.file('notes.txt', missing as String);
  }
}
