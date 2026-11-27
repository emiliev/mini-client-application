// T-0065-AC5 (imports and format): the import resolver writes exactly the
// imports in use; generated Dart has zero diagnostics under mc_analysis and
// is already formatted the way the repo's format gate wants.

import 'dart:convert';
import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _self = 'package:pkg/src/a.dart';

SymbolTable _table() => SymbolTable()
  ..define('Foo', 'package:pkg/src/foo.dart')
  ..define('Bar', 'package:pkg/src/bar.dart')
  ..define('A', _self)
  ..external('immutable', 'package:meta/meta.dart')
  ..external('FutureOr', 'dart:async')
  ..external('Money', 'package:mc_formatters/mc_formatters.dart');

ResolvedLibrary _resolve(List<String> code) => resolveLibrary(
  DartLibrary(
    'lib/src/a.dart',
    decls: [for (final c in code) RawDecl(Code(c))],
  ),
  _table(),
  selfUri: _self,
);

/// Analysis setup for a generated module in [dir]: the repo's package
/// config (made absolute) plus the module itself, and mc_analysis.
void _analysable(String dir, String package) {
  final rootConfig = File(
    p.join(repoRoot, '.dart_tool', 'package_config.json'),
  );
  if (!rootConfig.existsSync()) {
    // What tool/checks/lib/format_gate.sh does in a fresh worktree.
    final r = Process.runSync(Platform.resolvedExecutable, [
      'pub',
      'get',
      '--offline',
    ], workingDirectory: repoRoot);
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }
  final base = Uri.directory(p.join(repoRoot, '.dart_tool'));
  final j = jsonDecode(rootConfig.readAsStringSync()) as Map<String, Object?>;
  final packages = [
    for (final e in (j['packages']! as List).cast<Map<String, Object?>>())
      {...e, 'rootUri': base.resolve(e['rootUri']! as String).toString()},
    {
      'name': package,
      'rootUri': '../',
      'packageUri': 'lib/',
      'languageVersion': '3.13',
    },
  ];
  writeFile(
    Directory(dir),
    '.dart_tool/package_config.json',
    jsonEncode({'configVersion': 2, 'packages': packages}),
  );
  writeFile(
    Directory(dir),
    'analysis_options.yaml',
    'include: package:mc_analysis/analysis_options.yaml\n\nformatter:\n  trailing_commas: preserve\n',
  );
}

ProcessResult _dart(List<String> args, String dir) =>
    Process.runSync(Platform.resolvedExecutable, args, workingDirectory: dir);

List<String> _imports(String source) => [
  for (final l in source.split('\n'))
    if (l.startsWith('import ')) l,
];

void main() {
  group('T-0065-AC5 the import resolver', () {
    test('T-0065-AC5 imports exactly the libraries referenced, sorted, without itself', () {
      final r = _resolve([
        'class X extends ${ref('Foo')} {}',
        '@${ref('immutable')}\nclass Y { final ${ref('A')} a; final ${ref('String')} s; }',
      ]);
      expect(r.imports, ['package:meta/meta.dart', 'package:pkg/src/foo.dart']);
      expect(r.packages, ['meta', 'pkg']);
    });

    test('T-0065-AC5 adding a reference adds its import; removing it removes the import', () {
      final base = ['class X extends ${ref('Foo')} {}'];
      expect(_resolve(base).imports, ['package:pkg/src/foo.dart']);
      final added = [
        ...base,
        '${ref('FutureOr')}<${ref('Money')}> f() => throw 0;',
      ];
      expect(_resolve(added).imports, [
        'dart:async',
        'package:mc_formatters/mc_formatters.dart',
        'package:pkg/src/foo.dart',
      ]);
      expect(_resolve(['class X {}']).imports, isEmpty);
    });

    test('T-0065-AC5 directives follow directives_ordering', () {
      final lib = DartLibrary(
        'lib/src/a.dart',
        exports: [
          const Exports(['Bar', 'Foo']),
        ],
        parts: ['a.freezed.dart'],
        decls: [
          RawDecl(Code('${ref('FutureOr')}<${ref('Foo')}> f() => throw 0;')),
        ],
      );
      expect(renderLibrary(resolveLibrary(lib, _table(), selfUri: _self)), '''
import 'dart:async';

import 'package:pkg/src/foo.dart';

export 'package:pkg/src/bar.dart' show Bar;
export 'package:pkg/src/foo.dart' show Foo;

part 'a.freezed.dart';

FutureOr<Foo> f() => throw 0;
''');
    });

    test(
      'T-0065-AC5 an unknown or ambiguous reference is an error, never a guess',
      () {
        expect(
          () => _resolve(['${ref('Nope')} x;']),
          throwsA(
            isA<SymbolError>().having(
              (e) => e.message,
              'message',
              'lib/src/a.dart: unknown symbol "Nope": no emitted declaration or registered dependency defines it',
            ),
          ),
        );
        final t = _table()..external('Foo', 'package:other/other.dart');
        expect(
          () => resolveLibrary(
            DartLibrary(
              'lib/src/a.dart',
              decls: [RawDecl(Code('${ref('Foo')} x;'))],
            ),
            t,
          ),
          throwsA(
            isA<SymbolError>().having(
              (e) => e.message,
              'message',
              contains('ambiguous symbol "Foo"'),
            ),
          ),
        );
        expect(
          resolveLibrary(
            DartLibrary(
              'lib/src/a.dart',
              decls: [
                RawDecl(
                  Code('${ref('Foo', from: 'package:other/other.dart')} x;'),
                ),
              ],
            ),
            t,
          ).imports,
          ['package:other/other.dart'],
        );
        expect(
          () => SymbolTable().define('String', _self),
          throwsA(isA<SymbolError>()),
        );
      },
    );

    test('T-0065-AC5 the use-graph gives the pubspec dependencies and dev dependencies', () {
      final t = _table()..external('test', 'package:test/test.dart');
      final libs = [
        resolveLibrary(
          DartLibrary(
            'lib/src/a.dart',
            decls: [RawDecl(Code('@${ref('immutable')} class Z {}'))],
          ),
          t,
          selfUri: _self,
        ),
        resolveLibrary(
          DartLibrary(
            'test/a_test.dart',
            decls: [
              RawDecl(
                Code(
                  'void main() => ${ref('test')}(${ref('Foo')}, ${ref('immutable')});',
                ),
              ),
            ],
          ),
          t,
        ),
      ];
      final g = UseGraph('pkg', libs);
      expect(g.libDeps, ['meta']);
      expect(g.devDeps, ['test']);
      expect(g.edges, {
        'lib/src/a.dart': ['package:meta/meta.dart'],
        'test/a_test.dart': [
          'package:meta/meta.dart',
          'package:pkg/src/foo.dart',
          'package:test/test.dart',
        ],
      });
    });
  });

  group('T-0065-AC5 generated Dart under mc_analysis and the format gate', () {
    late Directory root;
    late String module;

    setUpAll(() {
      root = helloRoot('analyze');
      final r = mcgen(['gen', '--root', root.path, 'mc_hello']);
      expect(r.code, 0, reason: '$r');
      module = p.join(root.path, 'utility', 'mc_hello');
      _analysable(module, 'mc_hello');
    });
    tearDownAll(() => root.deleteSync(recursive: true));

    test(
      'T-0065-AC5 dart analyze with mc_analysis reports zero diagnostics',
      () {
        final r = _dart(['analyze', '--fatal-infos', '.'], module);
        expect('${r.stdout}', contains('No issues found!'));
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      },
    );

    test('T-0065-AC5 control: the analysis really runs mc_analysis (an unused import is caught)', () {
      final copy = tempRoot('analyze-control');
      addTearDown(() => copy.deleteSync(recursive: true));
      snapshot(module).forEach((k, v) => writeFile(copy, k, v));
      _analysable(copy.path, 'mc_hello');
      final mood = File(p.join(copy.path, 'lib/src/mood.dart'));
      mood.writeAsStringSync(
        mood.readAsStringSync().replaceFirst(
          '/// How',
          "import 'package:meta/meta.dart';\n\n/// How",
        ),
      );
      final r = _dart(['analyze', '--fatal-infos', '.'], copy.path);
      expect(r.exitCode, isNot(0));
      expect('${r.stdout}', contains('unused_import'));
    });

    test('T-0065-AC5 the output is formatted as the format gate formats (no change)', () {
      final r = _dart([
        'format',
        '--output=none',
        '--set-exit-if-changed',
        '.',
      ], module);
      expect(r.exitCode, 0, reason: '${r.stdout}');
      expect('${r.stdout}', contains('(0 changed)'));
    });

    test('T-0065-AC5 the committed golden equals the output, so the repo gate formats it too', () {
      // test/golden/utility_hello sits under tool/, which
      // tool/checks/lib/format_gate.sh formats; it is the generated tree.
      final golden = snapshot(
        p.join(mcgenDir, 'test', 'golden', 'utility_hello'),
      );
      final out = snapshot(module)
        ..remove('mcgen.yaml')
        ..remove('analysis_options.yaml');
      expect(out, golden);
    });

    test('T-0065-AC5 removing the reference in the spec removes the import, and stays clean', () {
      final noMood = helloSpec.replaceFirst(
        '      - {name: mood, type: Mood, default: calm}\n',
        '',
      );
      final r2 = helloRoot('analyze-nomood', spec: noMood);
      addTearDown(() => r2.deleteSync(recursive: true));
      expect(mcgen(['gen', '--root', r2.path, 'mc_hello']).code, 0);
      final dir = p.join(r2.path, 'utility', 'mc_hello');
      expect(_imports(readFile(r2, 'utility/mc_hello/lib/src/greeting.dart')), [
        "import 'package:meta/meta.dart';",
      ]);
      expect(
        _imports(readFile(root, 'utility/mc_hello/lib/src/greeting.dart')),
        [
          "import 'package:mc_hello/src/mood.dart';",
          "import 'package:meta/meta.dart';",
        ],
      );
      _analysable(dir, 'mc_hello');
      final r = _dart(['analyze', '--fatal-infos', '.'], dir);
      expect(r.exitCode, 0, reason: '${r.stdout}');
    });

    test('T-0065-AC5 the pubspec dependencies come from the use-graph', () {
      expect(
        readFile(root, 'utility/mc_hello/pubspec.yaml'),
        endsWith('\ndependencies:\n  meta: ^1.15.0\n'),
      );
    });
  });
}
