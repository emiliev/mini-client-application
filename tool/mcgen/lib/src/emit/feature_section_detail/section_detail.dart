// section_detail: the SC archetype (P2-05, T-0072). Its exemplars are
// feature/comics/comics_details and feature/characters/characters_details;
// `mcgen gen <module> --check` is the round-trip golden for each (plan 02
// KD1, ADR-0017).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/kit_symbols.dart';
import 'package:mcgen/src/emit/feature_section_detail/blocs.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/domain.dart';
import 'package:mcgen/src/emit/feature_section_detail/flow.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';
import 'package:mcgen/src/emit/feature_section_detail/package.dart';
import 'package:mcgen/src/emit/feature_section_detail/pages.dart';
import 'package:mcgen/src/emit/feature_section_detail/tests.dart';

class SectionDetailArchetype extends Archetype {
  const SectionDetailArchetype();

  @override
  String get name => 'section_detail';

  @override
  Set<Tier> get tiers => const {Tier.feature};

  @override
  List<Diagnostic> lint(ModuleSpec spec) => ScModel.lint(spec);

  @override
  void emit(EmitContext ctx) {
    final m = ScModel.parse(ctx.spec);
    registerKitSymbols(ctx.symbols);
    registerScSymbols(ctx.symbols);
    // gen-l10n's output: generated at build time, never by mcgen.
    ctx.symbols.external(
      m.l10nClass,
      'package:${m.module}/src/l10n/${m.module}_l10n.dart',
    );
    emitDomain(ctx, m);
    emitFlow(ctx, m);
    emitBlocs(ctx, m);
    emitPages(ctx, m);
    emitPackage(ctx, m);
    emitTests(ctx, m);
    final unused = m.unusedProse;
    if (unused.isNotEmpty) {
      throw StateError(
        'options.prose has slot(s) no template uses: ${unused.join(', ')}',
      );
    }
  }
}
