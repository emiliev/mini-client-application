// `mcgen spec lint`: the semantic checks on top of the schema (plan 02
// section 2.1). Every diagnostic carries the spec file, line and YAML path.

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/config.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/l10n_names.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:yaml/yaml.dart';

/// What lint knows besides the spec itself.
class LintContext {
  const LintContext({
    required this.index,
    required this.config,
    required this.archetypes,
    this.specs = const [],
  });

  final RepoIndex index;
  final McgenConfig config;
  final Map<String, Archetype> archetypes;

  /// Every spec being linted together (cross-spec collisions, tiers of
  /// modules that have no pubspec yet).
  final List<ModuleSpec> specs;

  /// The tier and location of first-party package [name], or null.
  ({Tier tier, String dir})? firstParty(
    String name, {
    required ModuleSpec except,
  }) {
    for (final s in specs) {
      if (s.module == name && !identical(s, except)) {
        return (tier: s.tier, dir: s.moduleDir);
      }
    }
    for (final pkg in index.named(name)) {
      return (tier: pkg.tier, dir: pkg.dir);
    }
    return null;
  }
}

/// The scenario id format: `MC-<module>-<two or more digits>`.
RegExp scenarioIdPattern(String module) =>
    RegExp('^MC-${RegExp.escape(module)}-[0-9]{2,}\$');

List<Diagnostic> lintSpec(ModuleSpec spec, LintContext ctx) {
  final out = <Diagnostic>[];
  void err(YamlNode node, String path, String code, String message) => out.add(
    Diagnostic.at(
      node,
      code: code,
      message: message,
      file: spec.file,
      yamlPath: path,
    ),
  );
  final root = spec.node as YamlMap;

  // --- archetype -------------------------------------------------------------
  final archetype = ctx.archetypes[spec.archetype];
  if (archetype == null) {
    final known = ctx.archetypes.keys.toList()..sort();
    err(
      root.nodes['archetype']!,
      'archetype',
      'archetype',
      'unknown archetype "${spec.archetype}" (known: ${known.join(', ')})',
    );
  } else if (!archetype.tiers.contains(spec.tier)) {
    err(
      root.nodes['tier']!,
      'tier',
      'archetype',
      'archetype "${spec.archetype}" is for ${archetype.tiers.map((t) => t.name).join('/')} modules, not ${spec.tier.name}',
    );
  }

  // --- module location and name ---------------------------------------------
  final dirTier = spec.moduleDir.split('/').first;
  if (dirTier != spec.tier.name) {
    err(
      root.nodes['tier']!,
      'tier',
      'tier',
      'tier "${spec.tier.name}" but the spec is under $dirTier/',
    );
  }
  final dirName = spec.moduleDir.split('/').last;
  if (dirName != spec.module) {
    err(
      root.nodes['module']!,
      'module',
      'name-collision',
      'module "${spec.module}" must live in a directory of the same name, not "$dirName"',
    );
  }
  for (final pkg in ctx.index.named(spec.module)) {
    if (pkg.dir != spec.moduleDir) {
      err(
        root.nodes['module']!,
        'module',
        'name-collision',
        'module "${spec.module}" is already the package at ${pkg.dir}',
      );
    }
  }
  for (final other in ctx.specs) {
    if (!identical(other, spec) &&
        other.module == spec.module &&
        other.file != spec.file) {
      err(
        root.nodes['module']!,
        'module',
        'name-collision',
        'module "${spec.module}" is also specified by ${other.file}',
      );
    }
  }

  // --- deps: D1 layering and the design-system rule -------------------------
  for (final key in ['deps', 'dev_deps']) {
    final list = root.nodes[key];
    if (list is! YamlList) continue;
    for (final (i, n) in list.nodes.indexed) {
      final dep = n.value as String;
      final path = '$key[$i]';
      if (dep == spec.module) {
        err(n, path, 'layering', 'a module cannot depend on itself');
        continue;
      }
      if (dep == 'mc_design_system') {
        err(
          n,
          path,
          'design-system-dep',
          '"mc_design_system" is never a direct dependency; depend on the mc_ds_* kit you use',
        );
        continue;
      }
      final fp = ctx.firstParty(dep, except: spec);
      if (fp == null) {
        if (!ctx.config.thirdParty.containsKey(dep) &&
            !ctx.config.sdkPackages.contains(dep)) {
          err(
            n,
            path,
            'unknown-dep',
            '"$dep" is not a first-party package, nor listed in tool/mcgen/mcgen.yaml third_party or sdk_packages',
          );
        }
        continue;
      }
      final allowed = switch (spec.tier) {
        Tier.app => true,
        Tier.feature => fp.tier == Tier.utility,
        Tier.utility => fp.tier == Tier.utility,
      };
      if (!allowed) {
        err(
          n,
          path,
          'layering',
          '${spec.tier.name} → ${fp.tier.name} dependency on "$dep" (${fp.dir}); '
              'D1: ${spec.tier.name == 'feature' ? 'features' : 'utilities'} depend on utilities only',
        );
      }
    }
  }

  // --- names -----------------------------------------------------------------
  final typeNames = <String, (YamlNode, String)>{};
  void typeName(String name, YamlNode node, String path) {
    final prev = typeNames[name];
    if (prev != null) {
      err(
        node,
        path,
        'name-collision',
        '"$name" is already declared at line ${prev.$1.span.start.line + 1} (${prev.$2})',
      );
    } else {
      typeNames[name] = (node, path);
    }
  }

  void unique<T>(
    Iterable<T> items,
    String Function(T) name,
    YamlNode Function(T) node,
    String Function(T) path,
    String what,
  ) {
    final seen = <String, YamlNode>{};
    for (final item in items) {
      final n = name(item);
      final prev = seen[n];
      if (prev != null) {
        err(
          node(item),
          path(item),
          'name-collision',
          'duplicate $what "$n" (first at line ${prev.span.start.line + 1})',
        );
      } else {
        seen[n] = node(item);
      }
    }
  }

  for (final e in spec.entities) {
    typeName(e.name, e.nodeOf('name'), '${e.path}.name');
    unique(
      e.fields,
      (f) => f.name,
      (f) => f.nodeOf('name'),
      (f) => '${f.path}.name',
      'field',
    );
    final variants = e.node is YamlMap
        ? (e.node as YamlMap).nodes['union']
        : null;
    if (variants is YamlList) {
      unique(
        [...variants.nodes.indexed],
        (v) => e.variants[v.$1].name,
        (v) => v.$2,
        (v) => '${e.path}.union[${v.$1}]',
        'union variant',
      );
    }
  }
  for (final b in spec.blocs) {
    typeName('${b.name}Bloc', b.nodeOf('name'), '${b.path}.name');
  }
  for (final s in spec.screens) {
    typeName(s.name, s.nodeOf('name'), '${s.path}.name');
  }
  for (final m in spec.mixins) {
    typeName(m.name, m.nodeOf('name'), '${m.path}.name');
  }
  if (spec.navigator case final nav?) {
    typeName(nav.name, nav.nodeOf('name'), 'navigator.name');
    final outbound = (nav.node as YamlMap).nodes['outbound'];
    if (outbound is YamlList) {
      unique(
        [...outbound.nodes.indexed],
        (o) => nav.outbound[o.$1].name,
        (o) => o.$2,
        (o) => 'navigator.outbound[${o.$1}]',
        'navigator method',
      );
    }
  }
  unique(
    spec.endpoints,
    (e) => e.id,
    (e) => e.nodeOf('id'),
    (e) => '${e.path}.id',
    'endpoint id',
  );
  unique(
    spec.rules,
    (r) => r.id,
    (r) => r.nodeOf('id'),
    (r) => '${r.path}.id',
    'rule id',
  );

  // --- rules need examples (C8: tests come only from examples) --------------
  for (final r in spec.rules) {
    if (r.examples.isEmpty) {
      err(
        r.nodeOf('id'),
        '${r.path}.examples',
        'rule-examples',
        'rule "${r.id}" has no examples; every rule needs at least one (plan 02 C8)',
      );
    }
  }

  // --- BDD scenario ids --------------------------------------------------------
  final idRe = scenarioIdPattern(spec.module);
  final ids = <String, YamlNode>{};
  final ruleIds = {for (final r in spec.rules) r.id};
  for (final f in spec.bdd) {
    for (final s in f.scenarios) {
      if (s.id == null && !spec.exemplar) {
        err(
          s.nodeOf('title'),
          '${s.path}.id',
          'scenario-id',
          'scenario "${s.title}" needs an id (MC-${spec.module}-NN); only an exemplar\'s scenarios may go without (ADR-0017)',
        );
      }
      if (s.examples.isNotEmpty) {
        final width = s.examples.first.length;
        for (final (i, row) in s.examples.indexed) {
          if (row.length != width) {
            err(
              s.nodeOf('examples'),
              '${s.path}.examples[$i]',
              'bdd',
              'Examples row ${i + 1} has ${row.length} cell(s); the header has $width',
            );
          }
        }
      }
    }
    final entries = <(String, YamlNode, String)>[
      for (final s in f.scenarios)
        if (s.id case final id?) (id, s.nodeOf('id'), '${s.path}.id'),
      for (final o in f.outlines) (o.id, o.nodeOf('id'), '${o.path}.id'),
    ];
    for (final (id, node, path) in entries) {
      if (!idRe.hasMatch(id)) {
        err(
          node,
          path,
          'scenario-id',
          'scenario id "$id" must match MC-${spec.module}-NN (two or more digits)',
        );
      }
      final prev = ids[id];
      if (prev != null) {
        err(
          node,
          path,
          'scenario-id',
          'duplicate scenario id "$id" (first at line ${prev.span.start.line + 1})',
        );
      } else {
        ids[id] = node;
      }
    }
    for (final o in f.outlines) {
      if (!ruleIds.contains(o.rule)) {
        err(
          o.nodeOf('rule'),
          '${o.path}.rule',
          'rule-examples',
          'outline "${o.id}" runs rule "${o.rule}", which the spec does not define',
        );
      }
    }
  }

  // --- ownership -------------------------------------------------------------
  if (spec.exemplar && spec.ownership != Ownership.ejected) {
    err(
      root.nodes['exemplar']!,
      'exemplar',
      'ownership',
      'an exemplar is hand-built, so it is ejected; this one is ${spec.ownership.name}',
    );
  }
  if (spec.owned.isNotEmpty &&
      spec.ownership != Ownership.mixed &&
      !spec.exemplar) {
    err(
      root.nodes['owned']!,
      'owned',
      'ownership',
      '"owned" files only exist in mixed modules and exemplars; this one is ${spec.ownership.name}',
    );
  }

  // --- gen-l10n reads a locale out of the ARB file name (F-0066) -------------
  // Only a module with strings has ARB files.
  final locales = [...?spec.l10n?.locales]..sort();
  for (final locale in locales) {
    final read = genL10nFileLocale('${spec.module}_$locale');
    if (read != locale) {
      err(
        root.nodes['module']!,
        'module',
        'l10n-name',
        'gen-l10n reads ${spec.module}_$locale.arb as locale "$read", not "$locale" '
            '(F-0066): rename the module so no "_<segment>" after its first '
            'parses as a locale (e.g. auth_signin, not auth_sign_in)',
      );
      break;
    }
  }

  // The archetype's own rules only make sense for a tier it supports.
  if (archetype != null && archetype.tiers.contains(spec.tier)) {
    out.addAll(archetype.lint(spec));
  }
  out.sort();
  return out;
}
