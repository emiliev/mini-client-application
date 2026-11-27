// The extension point P2-04 to P2-07 implement: one [Archetype] per module
// kind, registered in lib/src/archetypes.dart.

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';

abstract class Archetype {
  const Archetype();

  /// The spec's `archetype:` value (`list_detail`, `form_wizard`, ...).
  String get name;

  /// The tiers a module of this archetype may be in.
  Set<Tier> get tiers;

  /// Archetype-specific spec checks (run by `spec lint` and before `gen`),
  /// including the shape of `spec.options`. Report with [Diagnostic.at] on
  /// the spec's nodes so the line is precise.
  List<Diagnostic> lint(ModuleSpec spec) => const [];

  /// Emits the module into [ctx]: Dart libraries (IR), bricks and plain
  /// files. Must be a pure function of `ctx.spec`, `ctx.rng` and the tool's
  /// templates: no clock, no environment, no absolute paths.
  void emit(EmitContext ctx);
}
