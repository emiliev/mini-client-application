// T-0074: `mcgen wire` (plan 02 section 2.8). The wire-owned files of the
// repo regenerate byte for byte; a new list-detail spec gets its flow scope,
// a generated wiring group and a place in the app's lists, the catalogue
// included, with no hand edit.

import 'dart:io';

import 'package:mcgen/src/core/roundtrip.dart' show listTree;
import 'package:mcgen/src/wire/app.dart';
import 'package:mcgen/src/wire/flow_scope.dart';
import 'package:mcgen/src/wire/groups.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

void _copy(Directory root, String rel) {
  final src = File(p.join(repoRoot, rel));
  File(p.join(root.path, rel))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(src.readAsBytesSync());
}

void _copyTree(Directory root, String rel, {bool Function(String)? where}) {
  for (final f in listTree(p.join(repoRoot, rel))) {
    if (f.startsWith('.dart_tool/') || !(where?.call(f) ?? true)) continue;
    _copy(root, '$rel/$f');
  }
}

/// A temp root with what wire reads: the root and app pubspecs, every
/// wiring's pubspec, app_core's `AppLocations`, the utility packages'
/// pubspecs and libraries, and the given feature packages.
Directory _root(String tag, {List<String> features = const []}) {
  final root = tempRoot('T-0074-wire-$tag');
  addTearDown(() => root.deleteSync(recursive: true));
  _copy(root, 'pubspec.yaml');
  _copy(root, appPubspecPath);
  _copy(root, appWiringsBzlPath);
  _copy(root, appWiringsPath);
  _copy(root, generatedLocationsPath);
  _copy(root, 'app/wiring/app_core/lib/src/locations/app_locations.dart');
  for (final d in Directory(p.join(repoRoot, 'app/wiring')).listSync()) {
    final rel = p.relative(d.path, from: repoRoot);
    if (File(p.join(d.path, 'pubspec.yaml')).existsSync()) {
      _copy(root, '$rel/pubspec.yaml');
    }
  }
  for (final d in Directory(p.join(repoRoot, 'utility')).listSync()) {
    if (d is! Directory) continue;
    final rel = p.relative(d.path, from: repoRoot);
    _copyTree(
      root,
      rel,
      where: (f) => f == 'pubspec.yaml' || f.startsWith('lib/'),
    );
  }
  for (final f in features) {
    _copyTree(root, f);
  }
  return root;
}

const _probe = 'feature/zz_probe/zz_ld_probe';

void _addProbe(Directory root) {
  writeFile(root, '$_probe/mcgen.yaml', readFixture('zz_ld_probe/mcgen.yaml'));
}

void main() {
  group('T-0074-AC2 wire agrees with the wire-owned files it covers', () {
    test('T-0074-AC2 wire --check exits 0 on the repo, every covered file '
        'up to date', () {
      final r = mcgen(['wire', '--check'], cwd: repoRoot);
      expect(r.code, 0, reason: '$r');
      for (final f in [
        'pubspec.yaml',
        appPubspecPath,
        appWiringsPath,
        appWiringsBzlPath,
        generatedLocationsPath,
        'feature/characters/characters_list/$flowScopePath',
        'feature/trivia/trivia_quiz/$flowScopePath',
        'feature/store/store_home/$flowScopePath',
      ]) {
        expect(r.out, contains('$f: up to date'));
      }
      final scopes = RegExp(
        r'^feature/.*/lib/src/di/flow_scope\.dart: up to date$',
        multiLine: true,
      ).allMatches(r.out);
      expect(scopes, hasLength(greaterThanOrEqualTo(11)));
    });

    test('T-0074-AC2 a flow scope missing a root import fails --check, and '
        'wire restores it with its own doc comment', () {
      const f = 'feature/comics/comics_details';
      final root = _root('scope', features: [f]);
      final file = File(p.join(root.path, f, flowScopePath));
      final before = file.readAsStringSync();
      file.writeAsStringSync(
        before.replaceFirst('  RootImport<EventBus>(),\n', ''),
      );
      final c = mcgen(['wire', '--check', '--root', root.path]);
      expect(c.code, 1, reason: '$c');
      expect(c.err, contains('$f/$flowScopePath: out of date'));
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      expect(file.readAsStringSync(), before);
      expect(before, contains('HAND-WRITTEN FOR NOW'), reason: 'its prose');
    });

    test('T-0074-AC2 root imports: injectable constructors, modules and '
        'scope reads, minus what the package registers and the flow '
        'provides', () {
      final root = _root('derive');
      const f = 'feature/x/zz_scope';
      writeFile(root, '$f/pubspec.yaml', 'name: zz_scope\n');
      writeFile(root, '$f/lib/src/di/di_initializer.dart', '// init\n');
      writeFile(root, '$f/lib/src/navigator/zz_scope_navigator.dart', '''
abstract interface class ZzScopeNavigator {}
''');
      writeFile(root, '$f/lib/src/flow/zz_scope_flow.dart', '''
import 'package:mc_monitoring/mc_monitoring.dart';
final x = (scope) => scope.registerSingleton<Extra>(Extra());
final y = (context) => context.di<AnalyticsTracker>();
''');
      writeFile(root, '$f/lib/src/domain/repo.dart', '''
import 'package:dio/dio.dart';
import 'package:mc_session/mc_session.dart';

@injectable
class ZzRepo {
  const ZzRepo(this._dio, {required SessionReader session, Extra? extra});

  final Dio _dio;
}

@LazySingleton(as: ZzPort)
class ZzPortImpl implements ZzPort {
  ZzPortImpl(ZzRepo repo, @factoryParam String id);
}
''');
      writeFile(root, '$f/lib/src/presentation/bloc/bloc.dart', '''
import 'package:mc_monitoring/mc_monitoring.dart';

@injectable
final class ZzBloc {
  ZzBloc(this._port, this._navigator, Monitoring monitoring, this._flow);

  final ZzPort _port;
  final ZzScopeNavigator _navigator;
  final FeatureFlowController<ZzState> _flow;
}
''');
      writeFile(root, '$f/lib/src/di/di_module.dart', '''
import 'package:mc_storage/mc_storage.dart';

@module
abstract class ZzModule {
  @lazySingleton
  ZzHistory history(FileStore store) => ZzHistory(store);
}
''');
      final imports = rootImports('zz_scope', p.join(root.path, f), root.path);
      expect(
        [for (final i in imports) i.type],
        [
          'AnalyticsTracker',
          'Dio',
          'FileStore',
          'Monitoring',
          'SessionReader',
        ],
      );
      expect(
        {for (final i in imports) i.type: i.uri}['FileStore'],
        'package:mc_storage/mc_storage.dart',
      );
    });

    test('T-0074-AC2 the workspace members: sorted, every package under '
        'app/, feature/ and utility/, the others kept', () {
      const pubspec =
          'name: w\n\nworkspace:\n  - utility/b\n  - spike/x\n  - utility/a\n'
          '  - feature/gone/old\n\nenvironment: {}\n';
      expect(
        workspaceMembers(pubspec, ['utility/a', 'utility/b', 'app/new']),
        'name: w\n\nworkspace:\n  - app/new\n  - spike/x\n  - utility/a\n'
        '  - utility/b\n\nenvironment: {}\n',
      );
    });

    test('T-0074-AC2 the app pubspec: its *_wiring deps are the groups, in '
        'the sorted block, the rest untouched', () {
      const pubspec =
          'name: app\n\ndependencies:\n  a_wiring: any\n  b: any\n'
          '  flutter:\n    sdk: flutter\n  old_wiring: any\n\ndev_dependencies:\n'
          '  x: any\n';
      final plan = GroupPlan([
        WiringGroup('a', generated: false),
        WiringGroup('c', generated: true),
      ]);
      expect(
        appWiringDeps(pubspec, plan),
        'name: app\n\ndependencies:\n  a_wiring: any\n  b: any\n'
        '  c_wiring: any\n  flutter:\n    sdk: flutter\n\ndev_dependencies:\n'
        '  x: any\n',
      );
    });

    test('T-0074-AC2 a generated flow in a hand-written group is left '
        'unwired: a warning naming the group and F-0074, and a catalogue '
        'note, with no generated group and wire exiting 0', () {
      final root = _root('hand-group');
      writeFile(
        root,
        'feature/comics/zz_more_comics/mcgen.yaml',
        readFixture('zz_ld_probe/mcgen.yaml')
            .replaceAll('zz_ld_probe', 'zz_more_comics')
            .replaceAll('ZzLdProbe', 'ZzMoreComics')
            .replaceAll('zzLdProbe', 'zzMoreComics'),
      );
      final r = mcgen(['wire', '--root', root.path]);
      expect(r.code, 0, reason: '$r');
      expect(
        r.err,
        contains('warning: feature/comics/zz_more_comics/mcgen.yaml'),
      );
      expect(r.err, contains('"publishing" is hand-written'));
      expect(r.err, contains('F-0074'));
      expect(
        readFile(root, appWiringsPath),
        contains("CatalogueEntry(\n    module: 'zz_more_comics',\n    note:"),
      );
      expect(
        Directory(p.join(root.path, 'app/wiring/comics_wiring')).existsSync(),
        isFalse,
      );
      final c = mcgen(['wire', '--check', '--root', root.path]);
      expect(c.code, 0, reason: 'a warning is not drift: $c');
    });
  });

  group('T-0074-AC3 a new list-detail spec reaches the app through wire', () {
    test(
      'T-0074-AC3 gen, wire and buildgen: the flow scope, a generated '
      'group, the app lists and the catalogue entry, then all up to date',
      () {
        final root = _root('probe');
        _addProbe(root);
        for (final args in [
          ['gen', 'zz_ld_probe'],
          ['wire'],
          ['buildgen'],
        ]) {
          final r = mcgen([...args, '--root', root.path]);
          expect(r.code, 0, reason: '${args.first}: $r');
        }
        String read(String rel) => readFile(root, rel);
        expect(read('$_probe/$flowScopePath'), contains('RootImport<Dio>()'));
        expect(read('$_probe/BUILD.bazel'), contains('name = "zz_ld_probe"'));
        const group = 'app/wiring/zz_probe_wiring';
        for (final f in [
          'pubspec.yaml',
          'BUILD.bazel',
          '.mcgen/wire.json',
          'lib/zz_probe_wiring.dart',
          'lib/src/routes/zz_probe_routes.dart',
          'lib/src/routes/route_targets.dart',
          'lib/src/routes/route_targets_impl.dart',
          'lib/src/di/di_initializer.dart',
          'lib/src/di/zz_probe_wiring_di_initializer.dart',
          'lib/src/navigators/zz_ld_probe_navigator_impl.dart',
          'test/routes_test.dart',
        ]) {
          expect(
            File(p.join(root.path, group, f)).existsSync(),
            isTrue,
            reason: f,
          );
        }
        expect(
          read('$group/lib/src/routes/zz_probe_routes.dart'),
          contains(
            "@TypedGoRoute<ZzLdProbeRoute>(path: '/zz-ld-probe', name: 'zz_ld_probe')",
          ),
        );
        expect(
          read('$group/lib/src/navigators/zz_ld_probe_navigator_impl.dart'),
          contains('routerRef.router.push(AppLocations.comic(id.value))'),
        );
        expect(
          read(generatedLocationsPath),
          contains("static const String zzLdProbe = '/zz-ld-probe';"),
        );
        expect(
          read(appWiringsPath),
          contains(
            "CatalogueEntry(module: 'zz_ld_probe', location: '/zz-ld-probe')",
          ),
        );
        expect(read(appWiringsPath), contains('  ...zzProbeRoutes,\n'));
        expect(
          read(appWiringsPath),
          contains('  ZzProbeWiringDIInitializer(),\n'),
        );
        expect(read(appPubspecPath), contains('  zz_probe_wiring: any\n'));
        expect(
          read(appWiringsBzlPath),
          contains('"//app/wiring/zz_probe_wiring",'),
        );
        expect(read('pubspec.yaml'), contains('  - $group\n'));
        expect(read('pubspec.yaml'), contains('  - $_probe\n'));
        for (final args in [
          ['gen', '--check', 'zz_ld_probe'],
          ['wire', '--check'],
          ['buildgen', '--check'],
        ]) {
          final r = mcgen([...args, '--root', root.path]);
          expect(r.code, 0, reason: '${args.first} --check: $r');
        }
      },
    );

    test('T-0074-AC3 the navigator skeleton is written once: an engineer\'s '
        'edit survives wire, and wire --check does not flag it', () {
      final root = _root('owned');
      _addProbe(root);
      expect(mcgen(['gen', 'zz_ld_probe', '--root', root.path]).code, 0);
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      final nav = File(
        p.join(
          root.path,
          'app/wiring/zz_probe_wiring/lib/src/navigators/zz_ld_probe_navigator_impl.dart',
        ),
      );
      final edited = nav.readAsStringSync().replaceFirst(
        'AppLocations.comic(id.value)',
        'AppLocations.comic(id.value + 0)',
      );
      nav.writeAsStringSync(edited);
      final c = mcgen(['wire', '--check', '--root', root.path]);
      expect(c.code, 0, reason: '$c');
      expect(
        c.out,
        contains('zz_ld_probe_navigator_impl.dart: up to date (owned)'),
      );
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      expect(nav.readAsStringSync(), edited);
    });
  });

  group('T-0074 review round: wire', () {
    /// [fixture]'s spec as module [module] under feature/zz_probe/.
    void addSpec(
      Directory root,
      String fixture,
      String module, {
      String Function(String)? edit,
    }) {
      var text = readFixture('$fixture/mcgen.yaml');
      if (module != fixture) {
        final from = pascal(fixture);
        final to = pascal(module);
        text = text
            .replaceAll(fixture, module)
            .replaceAll(from, to)
            .replaceAll(camel(fixture), camel(module));
      }
      writeFile(
        root,
        'feature/zz_probe/$module/mcgen.yaml',
        edit == null ? text : edit(text),
      );
    }

    const group = 'app/wiring/zz_probe_wiring';
    String nav(String m) =>
        '$group/lib/src/navigators/${m}_navigator_impl.dart';
    bool exists(Directory root, String rel) =>
        File(p.join(root.path, rel)).existsSync();

    test('T-0074-AC2 removing spec b: wire --check reports what it would '
        'delete, wire deletes b\'s navigator and entries, and a group with no '
        'flow left goes entirely', () {
      final root = _root('orphans');
      addSpec(root, 'zz_ld_probe', 'zz_ld_probe');
      addSpec(root, 'zz_ld_probe', 'zz_ld_other');
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      expect(exists(root, nav('zz_ld_other')), isTrue);
      final marker = readFile(root, '$group/.mcgen/wire.json');
      expect(
        marker,
        contains('"lib/src/navigators/zz_ld_other_navigator_impl.dart": "'),
      );

      Directory(p.join(root.path, 'feature/zz_probe/zz_ld_other')).deleteSync(
        recursive: true,
      );
      final c = mcgen(['wire', '--check', '--root', root.path]);
      expect(c.code, 1, reason: '$c');
      expect(
        c.err,
        contains(
          '${nav('zz_ld_other')}: out of date, no longer generated: would delete',
        ),
      );
      final w = mcgen(['wire', '--root', root.path]);
      expect(w.code, 0, reason: '$w');
      expect(
        w.out,
        contains('${nav('zz_ld_other')}: deleted (no longer generated)'),
      );
      expect(exists(root, nav('zz_ld_other')), isFalse);
      expect(exists(root, nav('zz_ld_probe')), isTrue);
      expect(
        readFile(root, generatedLocationsPath),
        isNot(contains('zzLdOther')),
      );
      expect(readFile(root, appWiringsPath), isNot(contains('zz_ld_other')));
      expect(mcgen(['wire', '--check', '--root', root.path]).code, 0);

      Directory(p.join(root.path, 'feature/zz_probe')).deleteSync(
        recursive: true,
      );
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      expect(Directory(p.join(root.path, group)).existsSync(), isFalse);
      expect(readFile(root, 'pubspec.yaml'), isNot(contains(group)));
      expect(
        readFile(root, appPubspecPath),
        isNot(contains('zz_probe_wiring')),
      );
      expect(
        readFile(root, appWiringsBzlPath),
        isNot(contains('zz_probe_wiring')),
      );
      expect(mcgen(['wire', '--check', '--root', root.path]).code, 0);
    });

    test('T-0074-AC2 an orphaned navigator someone edited stops wire (nothing '
        'written) until --force deletes it', () {
      final root = _root('orphan-edited');
      addSpec(root, 'zz_ld_probe', 'zz_ld_probe');
      addSpec(root, 'zz_ld_probe', 'zz_ld_other');
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      final f = File(p.join(root.path, nav('zz_ld_other')));
      f.writeAsStringSync('${f.readAsStringSync()}// mapped by hand\n');
      Directory(p.join(root.path, 'feature/zz_probe/zz_ld_other')).deleteSync(
        recursive: true,
      );
      final before = readFile(root, appWiringsPath);
      for (final args in [
        ['wire'],
        ['wire', '--check'],
      ]) {
        final r = mcgen([...args, '--root', root.path]);
        expect(r.code, 1, reason: '$r');
        expect(r.err, contains('orphan-owned: ${nav('zz_ld_other')}'));
      }
      expect(f.existsSync(), isTrue);
      expect(readFile(root, appWiringsPath), before, reason: 'nothing written');
      final forced = mcgen(['wire', '--force', '--root', root.path]);
      expect(forced.code, 0, reason: '$forced');
      expect(forced.out, contains('(forced over an edit)'));
      expect(f.existsSync(), isFalse);
    });

    test('T-0074-AC2 an ejected module whose package exists stays wired; one '
        'with no package is listed as not wired', () {
      final root = _root('ejected');
      addSpec(
        root,
        'zz_ld_probe',
        'zz_ld_probe',
        edit: (s) => s.replaceFirst('ownership: mixed', 'ownership: ejected'),
      );
      writeFile(
        root,
        'feature/zz_probe/zz_ld_probe/pubspec.yaml',
        'name: zz_ld_probe\n',
      );
      expect(mcgen(['wire', '--root', root.path]).code, 0);
      expect(exists(root, nav('zz_ld_probe')), isTrue);
      expect(
        readFile(root, appWiringsPath),
        contains("location: '/zz-ld-probe'"),
      );

      File(p.join(root.path, 'feature/zz_probe/zz_ld_probe/pubspec.yaml'))
          .deleteSync();
      final r = mcgen(['wire', '--root', root.path]);
      expect(r.code, 0, reason: '$r');
      expect(
        r.err,
        contains('not wired: ejected, and its package does not exist'),
      );
      expect(
        readFile(root, appWiringsPath),
        contains("note: 'not wired: ejected, and its package does not exist'"),
      );
    });

    test('T-0074-AC2 the repo-wide path routes managed search and '
        'section-detail flows (a query, an id); an archetype wire cannot route '
        'is a warning and a catalogue note, not a failure', () {
      final root = _root('archetypes');
      addSpec(root, 'zz_sr_probe', 'zz_sr_probe');
      addSpec(root, 'zz_sc_probe', 'zz_sc_probe');
      addSpec(
        root,
        'zz_ld_probe',
        'zz_xx_probe',
        edit: (s) =>
            s.replaceFirst('archetype: list_detail', 'archetype: zz_form'),
      );
      final r = mcgen(['wire', '--root', root.path]);
      expect(r.code, 0, reason: '$r');
      expect(
        r.err,
        contains('warning: feature/zz_probe/zz_xx_probe/mcgen.yaml: not wired'),
      );
      final routes = readFile(
        root,
        '$group/lib/src/routes/zz_probe_routes.dart',
      );
      expect(routes, contains("path: '/zz-sr-probe', name: 'zz_sr_probe'"));
      expect(routes, contains('const ZzSrProbeRoute({this.q});'));
      expect(routes, contains("path: '/zz-sc-probe/:id', name: 'zz_sc_probe'"));
      expect(routes, contains('const ZzScProbeRoute({required this.id});'));
      expect(routes, contains('  final int id;'));
      final impl = readFile(
        root,
        '$group/lib/src/routes/route_targets_impl.dart',
      );
      expect(impl, contains('initialQuery: query'));
      expect(impl, contains('issueId: zz_sc_probe.IssueId(id)'));
      final loc = readFile(root, generatedLocationsPath);
      expect(
        loc,
        contains("static String zzScProbe(int id) => '/zz-sc-probe/\$id';"),
      );
      expect(loc, contains('static String zzSrProbe([String? query])'));
      final list = readFile(root, appWiringsPath);
      expect(list, contains("location: '/zz-sc-probe/501500'"));
      expect(list, contains("location: '/zz-sr-probe'"));
      expect(list, contains("module: 'zz_xx_probe'"));
      expect(list, contains('wire cannot route a "zz_form" flow yet'));
      final drift = readFile(
        root,
        '$group/test/routes_test.dart',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        drift,
        contains(
          'GeneratedLocations.zzScProbe(501500), const ZzScProbeRoute(id: 501500).location',
        ),
      );
      expect(
        drift,
        contains(
          "GeneratedLocations.zzSrProbe('a & b'), const ZzSrProbeRoute(q: 'a & b').location",
        ),
      );
      expect(mcgen(['wire', '--check', '--root', root.path]).code, 0);
    });

    test('T-0074-AC2 root imports: the @factoryMethod member is the one '
        'injectable calls, and a @preResolve Future<T> registers T', () {
      final root = _root('factory');
      const f = 'feature/x/zz_fm';
      writeFile(root, '$f/pubspec.yaml', 'name: zz_fm\n');
      writeFile(root, '$f/lib/src/di/di_initializer.dart', '// init\n');
      writeFile(root, '$f/lib/src/flow/zz_fm_flow.dart', '// flow\n');
      writeFile(root, '$f/lib/src/domain/repo.dart', '''
import 'package:dio/dio.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

@injectable
class ZzStore {
  ZzStore._(this._session);

  final SessionReader _session;

  @factoryMethod
  @preResolve
  static Future<ZzStore> create(Dio dio, ZzPrefs prefs) async => ZzStore._(null);
}

@module
abstract class ZzModule {
  @preResolve
  @singleton
  Future<ZzPrefs> prefs(FileStore store) async => ZzPrefs();
}
''');
      final imports = rootImports('zz_fm', p.join(root.path, f), root.path);
      expect([for (final i in imports) i.type], ['Dio', 'FileStore']);
    });

    test('T-0074-AC2 every archetype\'s pubspec has the packages wire\'s flow '
        'scope imports (list-detail\'s whatever its blocs import)', () {
      for (final fixture in ['zz_ld_probe', 'zz_sr_probe', 'zz_sc_probe']) {
        final root = _root('pubspec-$fixture');
        addSpec(root, fixture, fixture);
        expect(mcgen(['gen', fixture, '--root', root.path]).code, 0);
        final dir = p.join(root.path, 'feature/zz_probe/$fixture');
        expect(mcgen(['wire', dir, '--root', root.path]).code, 0);
        final scope = File(p.join(dir, flowScopePath)).readAsStringSync();
        final pubspec = File(p.join(dir, 'pubspec.yaml')).readAsStringSync();
        final deps = pubspec.substring(
          pubspec.indexOf('dependencies:'),
          pubspec.indexOf('dev_dependencies:'),
        );
        for (final m in RegExp(r"import 'package:(\w+)/").allMatches(scope)) {
          expect(
            deps,
            contains('  ${m.group(1)}:'),
            reason: '$fixture: ${m.group(1)}',
          );
        }
        if (fixture == 'zz_ld_probe') {
          for (final pkg in ['dio', 'mc_di', 'mc_monitoring']) {
            expect(deps, contains('  $pkg:'), reason: pkg);
          }
        }
      }
    });

    test('T-0074-AC2 a comment inside the workspace or dependencies block is a '
        'clear error, not a lost line', () {
      expect(
        () => workspaceMembers('workspace:\n  - a\n  # why\n  - b\n', ['a']),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('comment inside "workspace:"'),
          ),
        ),
      );
      expect(
        () => appWiringDeps(
          'dependencies:\n  a: any\n  # why\n  b: any\n',
          GroupPlan([]),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('comment inside "dependencies:"'),
          ),
        ),
      );
    });
  });
}
