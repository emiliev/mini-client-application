// mcgen's library surface: the CLI entry point and the core, for tests and
// for archetypes (P2-04 to P2-07).

export 'package:mcgen/src/archetypes.dart' show archetypes;
export 'package:mcgen/src/cli.dart' show runMcgen;
export 'package:mcgen/src/core/archetype.dart';
export 'package:mcgen/src/core/brick.dart';
export 'package:mcgen/src/core/check.dart';
export 'package:mcgen/src/core/config.dart';
export 'package:mcgen/src/core/diagnostics.dart';
export 'package:mcgen/src/core/emit.dart';
export 'package:mcgen/src/core/format.dart';
export 'package:mcgen/src/core/generator.dart';
export 'package:mcgen/src/core/ir/code.dart';
export 'package:mcgen/src/core/ir/dart_ir.dart';
export 'package:mcgen/src/core/ir/render.dart';
export 'package:mcgen/src/core/ir/symbols.dart';
export 'package:mcgen/src/core/ir/use_graph.dart';
export 'package:mcgen/src/core/keep.dart';
export 'package:mcgen/src/core/l10n_names.dart';
export 'package:mcgen/src/core/lint.dart';
export 'package:mcgen/src/core/manifest.dart';
export 'package:mcgen/src/core/naming.dart';
export 'package:mcgen/src/core/repo.dart';
export 'package:mcgen/src/core/rng.dart';
export 'package:mcgen/src/core/roundtrip.dart';
export 'package:mcgen/src/core/spec/schema_validator.dart';
export 'package:mcgen/src/core/spec/spec.dart';
export 'package:mcgen/src/core/spec/types.dart';
export 'package:mcgen/src/core/writer.dart';
