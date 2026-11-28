// list_detail: the LD archetype (P2-04, T-0069). Its exemplar is
// feature/characters/characters_list; `mcgen gen characters_list --check`
// is the round-trip golden (plan 02 KD1, ADR-0017).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/kit_symbols.dart';
import 'package:mcgen/src/emit/feature_list_detail/blocs.dart';
import 'package:mcgen/src/emit/feature_list_detail/domain.dart';
import 'package:mcgen/src/emit/feature_list_detail/flow.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';
import 'package:mcgen/src/emit/feature_list_detail/package.dart';
import 'package:mcgen/src/emit/feature_list_detail/pages.dart';
import 'package:mcgen/src/emit/feature_list_detail/tests.dart';

class ListDetailArchetype extends Archetype {
  const ListDetailArchetype();

  @override
  String get name => 'list_detail';

  @override
  Set<Tier> get tiers => const {Tier.feature};

  @override
  List<Diagnostic> lint(ModuleSpec spec) => LdModel.lint(spec);

  @override
  void emit(EmitContext ctx) {
    final m = LdModel.parse(ctx.spec);
    registerKitSymbols(ctx.symbols);
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
