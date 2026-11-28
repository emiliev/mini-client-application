// dashboard: the DB archetype (P2-06, T-0076). Its exemplar is
// feature/store/store_home; `mcgen gen store_home --check` is the round-trip
// golden (plan 02 KD1, ADR-0017). It is the only DB module, so the probes
// (tool/mcgen/tool/T-0076-AC3_db_probe.sh) carry the generalisation proof.

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/feature_dashboard/blocs.dart';
import 'package:mcgen/src/emit/feature_dashboard/flow.dart';
import 'package:mcgen/src/emit/feature_dashboard/model.dart';
import 'package:mcgen/src/emit/feature_dashboard/package.dart';
import 'package:mcgen/src/emit/feature_dashboard/page.dart';
import 'package:mcgen/src/emit/feature_dashboard/tests.dart';
import 'package:mcgen/src/emit/feature_dashboard/text.dart';

class DashboardArchetype extends Archetype {
  const DashboardArchetype();

  @override
  String get name => 'dashboard';

  @override
  Set<Tier> get tiers => const {Tier.feature};

  @override
  List<Diagnostic> lint(ModuleSpec spec) => DbModel.lint(spec);

  @override
  void emit(EmitContext context) {
    final m = DbModel.parse(context.spec);
    final ctx = Out(context);
    emitFlow(ctx, m);
    emitBlocs(ctx, m);
    emitPage(ctx, m);
    emitTests(ctx, m);
    // The packages the generated files import, read back from what was
    // emitted (`lib/` and `test/` apart), so pubspec.yaml needs no list of
    // its own beyond what the owned files use (`deps`, `dev_deps`).
    emitPackage(
      ctx,
      m,
      libSources: ctx.texts((p) => p.startsWith('lib/')),
      testSources: ctx.texts((p) => p.startsWith('test/')),
    );
    final unused = m.unusedProse;
    if (unused.isNotEmpty) {
      throw StateError(
        'options.prose has slot(s) no template uses: ${unused.join(', ')}',
      );
    }
  }
}
