// The mcgen command line (plan 02 section 2.1).
//
// Exit codes: 0 ok; 1 problems found (lint errors, drift, a `--check` diff);
// 3 a command that is not implemented yet; 64 usage.

import 'dart:io';

import 'package:args/args.dart';
import 'package:mcgen/src/archetypes.dart' as registry;
import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/brick.dart';
import 'package:mcgen/src/core/check.dart';
import 'package:mcgen/src/core/config.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/format.dart';
import 'package:mcgen/src/core/generator.dart';
import 'package:mcgen/src/core/lint.dart';
import 'package:mcgen/src/core/manifest.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/spec/schema_validator.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/core/writer.dart';
import 'package:path/path.dart' as p;

const _notYet = {
  'wire': 'P2-08',
  'buildgen': 'P2-08',
  'owners': 'P2-08',
  'new': 'P2-08',
  'stats': 'P2-09',
  'synth': 'P2-15',
};

const _usage = '''
usage: mcgen <command> [options]

  spec lint [--all] [<module|path>...]     schema + semantic checks
  gen [--check] [--force] <module|path>... render modules (--check: dry run, exit 1 on any diff)
  gen --out <dir> <module|path>            render one module into an empty directory
  check [--all] [<module|path>...]         drift: hand edits, stale manifests, keep damage

  not yet: spec synth (P2-09), wire, buildgen, owners, new (P2-08), stats (P2-09), synth (P2-15)

common options:
  --root <dir>   the tree to work on (default: the git root above the working directory)
''';

/// Runs mcgen with [args]. [cwd] defaults to the process's working
/// directory; [dartExecutable] to the running VM (used for `dart format`).
int runMcgen(
  List<String> args, {
  StringSink? out,
  StringSink? err,
  String? cwd,
  String? dartExecutable,
  Map<String, Archetype>? archetypes,
}) {
  final o = out ?? stdout;
  final e = err ?? stderr;
  final workDir = cwd ?? Directory.current.path;
  if (args.isEmpty ||
      args.first == 'help' ||
      args.first == '--help' ||
      args.first == '-h') {
    (args.isEmpty ? e : o).write(_usage);
    return args.isEmpty ? 64 : 0;
  }
  final command = args.first;
  if (command == 'spec' && args.length > 1 && args[1] == 'synth') {
    e.writeln('mcgen spec synth: not yet (P2-09)');
    return 3;
  }
  if (_notYet.containsKey(command)) {
    e.writeln('mcgen $command: not yet (${_notYet[command]})');
    return 3;
  }
  final parser = ArgParser()
    ..addOption('root')
    ..addFlag('all', negatable: false);
  final rest = switch (command) {
    'spec' when args.length > 1 && args[1] == 'lint' => args.sublist(2),
    'gen' || 'check' => args.sublist(1),
    _ => null,
  };
  if (rest == null) {
    e
      ..writeln('mcgen: unknown command "${args.join(' ')}"')
      ..write(_usage);
    return 64;
  }
  if (command == 'gen') {
    parser
      ..addFlag('check', negatable: false)
      ..addFlag('force', negatable: false)
      ..addOption('out')
      ..addOption('bricks', hide: true);
  }
  final ArgResults opts;
  try {
    opts = parser.parse(rest);
  } on FormatException catch (x) {
    e
      ..writeln('mcgen: ${x.message}')
      ..write(_usage);
    return 64;
  }

  final root = opts.option('root') != null
      ? p.normalize(p.absolute(workDir, opts.option('root')))
      : findRepoRoot(workDir);
  if (root == null || !Directory(root).existsSync()) {
    e.writeln('mcgen: no root: pass --root, or run inside a git checkout');
    return 64;
  }
  final session = _Session(
    root,
    ToolLayout.current(
      bricksDir: command == 'gen' ? opts.option('bricks') : null,
    ),
    archetypes ?? registry.archetypes,
    dartExecutable,
  );
  try {
    final specs = session.resolve(
      opts.rest,
      all: opts.flag('all'),
      cwd: workDir,
    );
    return switch (command) {
      'spec' => session.lint(specs, o, e),
      'gen' when opts.option('out') != null => session.genOut(
        specs,
        opts.option('out')!,
        workDir,
        o,
        e,
      ),
      'gen' => session.gen(
        specs,
        check: opts.flag('check'),
        force: opts.flag('force'),
        out: o,
        err: e,
      ),
      _ => session.check(specs, o, e),
    };
  } on McgenException catch (x) {
    e.writeln(x);
    return 1;
  } on _UsageError catch (x) {
    e.writeln('mcgen: ${x.message}');
    return 64;
  }
}

class _UsageError implements Exception {
  _UsageError(this.message);

  final String message;
}

class _Session {
  _Session(this.root, this.tool, this.archetypes, String? dartExecutable)
    : config = tool.loadConfig(),
      schema = SpecSchema.load(tool.schemaPath),
      index = RepoIndex.scan(root) {
    generator = Generator(
      config: config,
      archetypes: archetypes,
      bricks: BrickSet(tool.bricksDir),
      formatter: DartFormatter(config, dartExecutable: dartExecutable),
    );
  }

  final String root;
  final ToolLayout tool;
  final Map<String, Archetype> archetypes;
  final McgenConfig config;
  final SpecSchema schema;
  final RepoIndex index;
  late final Generator generator;

  List<String> get forbidden => [
    root,
    tool.dir,
    Directory.systemTemp.resolveSymbolicLinksSync(),
    ?Platform.environment['HOME'],
  ];

  /// Root-relative spec paths for [targets].
  List<String> resolve(
    List<String> targets, {
    required bool all,
    required String cwd,
  }) {
    if (all) {
      if (targets.isNotEmpty) throw _UsageError('--all takes no modules');
      return index.specFiles;
    }
    if (targets.isEmpty) {
      throw _UsageError('name at least one module, or pass --all');
    }
    final out = <String>[];
    for (final t in targets) {
      if (t.contains('/') || t.endsWith('.yaml') || t == '.') {
        var abs = p.normalize(p.absolute(cwd, t));
        if (FileSystemEntity.isDirectorySync(abs)) {
          abs = p.join(abs, 'mcgen.yaml');
        }
        if (!File(abs).existsSync()) throw _UsageError('no spec at $t');
        if (!p.isWithin(root, abs)) throw _UsageError('$t is outside the root');
        out.add(p.posix.joinAll(p.split(p.relative(abs, from: root))));
      } else {
        final hits = [
          for (final s in index.specFiles)
            if (p.posix.basename(p.posix.dirname(s)) == t) s,
        ];
        if (hits.isEmpty) {
          throw _UsageError(
            'no spec for module "$t" under app/, feature/ or utility/',
          );
        }
        if (hits.length > 1) {
          throw _UsageError(
            'module "$t" has several specs: ${hits.join(', ')}',
          );
        }
        out.add(hits.single);
      }
    }
    return out;
  }

  ModuleSpec load(String rel) => loadSpec(
    text: File(p.join(root, rel)).readAsStringSync(),
    file: rel,
    schema: schema,
  );

  /// Loads every spec; diagnostics of the ones that fail go to [bad].
  List<ModuleSpec> loadAll(List<String> rels, List<Diagnostic> bad) {
    final specs = <ModuleSpec>[];
    for (final rel in rels) {
      try {
        specs.add(load(rel));
      } on McgenException catch (x) {
        bad.addAll(x.diagnostics);
      }
    }
    return specs;
  }

  int lint(List<String> rels, StringSink out, StringSink err) {
    final diags = <Diagnostic>[];
    final specs = loadAll(rels, diags);
    final ctx = LintContext(
      index: index,
      config: config,
      archetypes: archetypes,
      specs: specs,
    );
    for (final s in specs) {
      diags.addAll(lintSpec(s, ctx));
    }
    diags.sort();
    for (final d in diags) {
      err.writeln(d);
    }
    out.writeln(
      'mcgen spec lint: ${rels.length} spec(s), ${diags.length} error(s)',
    );
    return diags.isEmpty ? 0 : 1;
  }

  List<GeneratedModule> _generateAll(List<String> rels) {
    final diags = <Diagnostic>[];
    final specs = loadAll(rels, diags);
    if (diags.isNotEmpty) throw McgenException(diags..sort());
    final gens = <GeneratedModule>[];
    for (final s in specs) {
      try {
        gens.add(
          generator.generate(
            s,
            index: index,
            specs: specs.where((x) => !identical(x, s)).toList(),
            forbidden: forbidden,
          ),
        );
      } on McgenException catch (x) {
        diags.addAll(x.diagnostics);
      }
    }
    if (diags.isNotEmpty) throw McgenException(diags..sort());
    return gens;
  }

  int gen(
    List<String> rels, {
    required bool check,
    required bool force,
    required StringSink out,
    required StringSink err,
  }) {
    final gens = _generateAll(rels);
    final plans = [
      for (final g in gens)
        (g, planWrite(g, p.join(root, g.spec.moduleDir), force: force)),
    ];
    final drift = [for (final (_, plan) in plans) ...plan.drift];
    if (drift.isNotEmpty) {
      err.writeln(
        'mcgen gen: refusing to write anything: ${drift.length} drifted file(s)',
      );
      for (final d in drift) {
        err.writeln('  $d');
      }
      err.writeln(
        'remedies: move the edit into a keep region or the spec, add the file to owned: (mixed modules), or pass --force',
      );
      return 1;
    }
    var dirty = false;
    for (final (g, plan) in plans) {
      final dir = g.spec.moduleDir;
      for (final n in plan.notes) {
        out.writeln('$dir: $n');
      }
      if (plan.ejected) continue;
      if (plan.clean) {
        out.writeln(check ? '$dir: up to date' : '$dir: no changes');
        continue;
      }
      dirty = true;
      final verb = check ? 'would ' : '';
      out.writeln(
        check
            ? '$dir: out of date'
            : '$dir: wrote ${plan.changes.length + (plan.manifestChanged ? 1 : 0)} file(s)',
      );
      for (final c in plan.changes) {
        final forced = c.forced == null ? '' : ' (forced over ${c.forced})';
        out.writeln('  $verb${c.kind.name} $dir/${c.path}$forced');
      }
      if (plan.manifestChanged) {
        out.writeln('  ${verb}write $dir/$manifestPath');
      }
      if (!check) applyPlan(plan, p.join(root, dir));
    }
    return check && dirty ? 1 : 0;
  }

  int genOut(
    List<String> rels,
    String outDir,
    String cwd,
    StringSink out,
    StringSink err,
  ) {
    if (rels.length != 1) throw _UsageError('--out renders exactly one module');
    final dir = p.normalize(p.absolute(cwd, outDir));
    final d = Directory(dir);
    if (d.existsSync() && d.listSync().isNotEmpty) {
      throw _UsageError('--out $outDir is not empty');
    }
    final g = _generateAll(rels).single;
    for (final f in g.files.values) {
      File(p.join(dir, f.path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(f.content);
    }
    File(p.join(dir, manifestPath))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(g.manifest.encode());
    out.writeln(
      '${g.spec.moduleDir}: rendered ${g.files.length + 1} file(s) into $outDir',
    );
    return 0;
  }

  int check(List<String> rels, StringSink out, StringSink err) {
    final diags = <Diagnostic>[];
    final specs = loadAll(rels, diags);
    final drift = <Drift>[];
    for (final s in specs) {
      GeneratedModule? g;
      if (s.ownership != Ownership.ejected) {
        try {
          g = generator.generate(
            s,
            index: index,
            specs: specs.where((x) => !identical(x, s)).toList(),
            forbidden: forbidden,
          );
        } on McgenException catch (x) {
          diags.addAll(x.diagnostics);
        }
      }
      drift.addAll(checkModule(s, p.join(root, s.moduleDir), g));
    }
    diags.sort();
    drift.sort();
    for (final d in diags) {
      err.writeln(d);
    }
    for (final d in drift) {
      err.writeln(d);
    }
    out.writeln(
      'mcgen check: ${rels.length} module(s), ${drift.length} drift, ${diags.length} error(s)',
    );
    return drift.isEmpty && diags.isEmpty ? 0 : 1;
  }
}
