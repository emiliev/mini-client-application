// search: the SR archetype (P2-05, T-0073). Its exemplars are
// feature/discovery/discovery_search (grouped) and
// feature/characters/characters_search (paged); `mcgen gen <module> --check`
// is the round-trip golden for each (plan 02 KD1, ADR-0017).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/kit_symbols.dart';
import 'package:mcgen/src/emit/feature_search/blocs.dart';
import 'package:mcgen/src/emit/feature_search/flow.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/package.dart';
import 'package:mcgen/src/emit/feature_search/pages.dart';
import 'package:mcgen/src/emit/feature_search/skeleton.dart';
import 'package:mcgen/src/emit/feature_search/tests.dart';

class SearchArchetype extends Archetype {
  const SearchArchetype();

  @override
  String get name => 'search';

  @override
  Set<Tier> get tiers => const {Tier.feature};

  @override
  List<Diagnostic> lint(ModuleSpec spec) => SrModel.lint(spec);

  @override
  void emit(EmitContext ctx) {
    final m = SrModel.parse(ctx.spec);
    registerKitSymbols(ctx.symbols);
    // gen-l10n's output: generated at build time, never by mcgen.
    ctx.symbols.external(
      m.l10nClass,
      'package:${m.module}/src/l10n/${m.module}_l10n.dart',
    );
    emitFlow(ctx, m);
    emitBlocs(ctx, m);
    emitPages(ctx, m);
    emitPackage(ctx, m);
    emitTests(ctx, m);
    if (m.skeleton) emitSkeleton(ctx, m);
    final unused = m.unusedProse;
    if (unused.isNotEmpty) {
      throw StateError(
        'options.prose has slot(s) no template uses: ${unused.join(', ')}',
      );
    }
  }
}
