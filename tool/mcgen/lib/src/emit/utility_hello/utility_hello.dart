// utility_hello: the reference archetype mcgen's core is tested with
// (T-0065). A pure-Dart utility: a pubspec (brick), a barrel and one library
// per entity (IR). Not one of the seven exemplars; P2-04 to P2-07 add those.
//
// It exercises every core seam an archetype uses: the brick renderer, the
// IR, the symbol table (an external symbol, `@immutable`, and sibling
// references between entities), the import resolver, the use-graph (the
// pubspec dependencies), a seeded choice and a keep region.

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/ir/symbols.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/core/spec/types.dart';

/// What a model's default `render()` body may open with (a seeded pick).
const salutations = ['Greetings', 'Hello', 'Hi', 'Welcome'];

class UtilityHelloArchetype extends Archetype {
  const UtilityHelloArchetype();

  @override
  String get name => 'utility_hello';

  @override
  Set<Tier> get tiers => const {Tier.utility};

  @override
  List<Diagnostic> lint(ModuleSpec spec) {
    final out = <Diagnostic>[];
    void err(SpecPart part, String key, String path, String message) => out.add(
      Diagnostic.at(
        part.nodeOf(key),
        code: 'utility_hello',
        message: message,
        file: spec.file,
        yamlPath: path,
      ),
    );
    if (spec.description == null) {
      err(spec, 'module', 'description', 'utility_hello needs a description');
    }
    if (spec.options.isNotEmpty) {
      err(spec, 'options', 'options', 'utility_hello takes no options');
    }
    if (!spec.entities.any((e) => e.kind == EntityKind.model)) {
      err(
        spec,
        'module',
        'entities',
        'utility_hello needs at least one model entity',
      );
    }
    final local = {for (final e in spec.entities) e.name};
    final byName = {for (final e in spec.entities) e.name: e};
    for (final e in spec.entities) {
      if (e.kind == EntityKind.union) {
        err(e, 'union', '${e.path}.union', 'utility_hello has no unions');
      }
      for (final f in e.fields) {
        for (final t in f.type.names) {
          if (!local.contains(t) && !dartCoreNames.contains(t)) {
            err(
              f,
              'type',
              '${f.path}.type',
              'unknown type "$t": use dart:core types or entities of this spec',
            );
          }
        }
        final en = byName[f.type.name];
        if (f.hasDefault &&
            en != null &&
            en.kind == EntityKind.enumeration &&
            !en.values.contains(f.defaultValue)) {
          err(
            f,
            'default',
            '${f.path}.default',
            'default "${f.defaultValue}" is not a value of ${en.name} (${en.values.join(', ')})',
          );
        }
      }
    }
    return out;
  }

  @override
  void emit(EmitContext ctx) {
    final spec = ctx.spec;
    ctx.symbols.external('immutable', 'package:meta/meta.dart');
    final entities = {for (final e in spec.entities) e.name: e};
    for (final e in spec.entities) {
      final path = 'lib/src/${snakeCase(e.name)}.dart';
      switch (e.kind) {
        case EntityKind.model:
          ctx.library(DartLibrary(path, decls: [_model(ctx, e, entities)]));
        case EntityKind.enumeration:
          ctx.library(
            DartLibrary(
              path,
              decls: [
                EnumDecl(e.name, [
                  for (final v in e.values) EnumValue(v),
                ], doc: e.doc),
              ],
            ),
          );
        case EntityKind.union:
          throw StateError('unions are rejected by lint');
      }
    }
    ctx.library(
      DartLibrary(
        'lib/${spec.module}.dart',
        preamble: '// The public surface: every entity of the spec.\n',
        exports: [
          Exports([for (final e in spec.entities) e.name]),
        ],
      ),
    );
    ctx.deferred('pubspec.yaml', (graph) {
      final deps = {...spec.deps, ...graph.libDeps}.toList()..sort();
      final vars = {
        'name': spec.module,
        'description': spec.description!,
        'sdk': ctx.config.sdkConstraint,
        'has_dependencies': deps.isNotEmpty,
        'dependencies': [
          for (final d in deps) {'entry': ctx.packages.pubspecEntry(d)},
        ],
      };
      return ctx.bricks['utility_hello'].render(vars)['pubspec.yaml']!;
    });
  }

  ClassDecl _model(
    EmitContext ctx,
    EntitySpec e,
    Map<String, EntitySpec> entities,
  ) {
    Code type(TypeExpr t) => Code(_typeSource(t, entities.keys.toSet()));
    final params = [
      for (final f in e.fields)
        if (f.hasDefault)
          'this.${f.name} = ${_literal(f, entities)}'
        else if (f.type.nullable)
          'this.${f.name}'
        else
          'required this.${f.name}',
    ];
    final salutation = ctx.rng.fork('entities').fork(e.name).pick(salutations);
    final shown = e.fields.map((f) => '${f.name}: \$${f.name}').join(', ');
    return ClassDecl(
      e.name,
      doc: e.doc,
      annotations: [Code('@${ref('immutable')}')],
      members: [
        RawMember(
          Code(
            'const ${e.name}(${params.isEmpty ? '' : '{${params.join(', ')}}'});',
          ),
          doc: 'Creates a [${e.name}].',
        ),
        for (final f in e.fields)
          RawMember(
            Code.join([Code('final '), type(f.type), Code(' ${f.name};')]),
            doc: f.doc,
          ),
        Method(
          Code('String render()'),
          doc: 'This ${snakeCase(e.name).replaceAll('_', ' ')} as text.',
          body: Body([
            Keep('${snakeCase(e.name)}.render', [
              Code("return '$salutation, ${e.name}($shown)';"),
            ]),
          ]),
        ),
      ],
    );
  }

  static String _typeSource(TypeExpr t, Set<String> local) {
    final name = local.contains(t.name) ? ref(t.name) : t.name;
    final args = t.args.isEmpty
        ? ''
        : '<${t.args.map((a) => _typeSource(a, local)).join(', ')}>';
    return '$name$args${t.nullable ? '?' : ''}';
  }

  static String _literal(FieldSpec f, Map<String, EntitySpec> entities) {
    final v = f.defaultValue;
    final enumType = entities[f.type.name];
    if (enumType != null &&
        enumType.kind == EntityKind.enumeration &&
        v is String) {
      return '${ref(enumType.name)}.$v';
    }
    return switch (v) {
      null => 'null',
      bool() || int() || double() => '$v',
      String() => dartString(v),
      List() when v.isEmpty => 'const []',
      Map() when v.isEmpty => 'const {}',
      _ => throw StateError(
        '${f.path}: utility_hello cannot write the default $v',
      ),
    };
  }
}
