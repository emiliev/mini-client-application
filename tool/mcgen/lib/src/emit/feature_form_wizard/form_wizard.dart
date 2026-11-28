// form_wizard: the FW archetype (P2-06, T-0075). Its exemplars are
// feature/library/library_reading_list_editor (a three-step wizard with a
// flow result) and feature/auth/auth_signin (one form page); `mcgen gen
// <module> --check` is the round-trip golden for each (plan 02 KD1,
// ADR-0017).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/kit_symbols.dart';
import 'package:mcgen/src/emit/feature_form_wizard/flow.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';
import 'package:mcgen/src/emit/feature_form_wizard/package.dart';
import 'package:mcgen/src/emit/feature_form_wizard/skeleton.dart';
import 'package:mcgen/src/emit/feature_form_wizard/tests.dart';

class FormWizardArchetype extends Archetype {
  const FormWizardArchetype();

  @override
  String get name => 'form_wizard';

  @override
  Set<Tier> get tiers => const {Tier.feature};

  @override
  List<Diagnostic> lint(ModuleSpec spec) => FwModel.lint(spec);

  @override
  void emit(EmitContext ctx) {
    final m = FwModel.parse(ctx.spec);
    registerKitSymbols(ctx.symbols);
    // A skeleton writes the files that define some of the module's own
    // types; every other type of `options.types` is a dependency's or a
    // hand-written file's.
    final defined = skeletonDefines(m);
    for (final e in m.types.entries) {
      final uri = m.uriOf(e.value);
      // The kit table may know the name already (`Monitoring`).
      if (!defined.contains(e.key) &&
          !ctx.symbols.lookup(e.key).any((d) => d.library == uri)) {
        ctx.symbols.external(e.key, uri);
      }
    }
    // gen-l10n's output: generated at build time, never by mcgen.
    ctx.symbols.external(
      m.l10nClass,
      'package:${m.module}/src/l10n/${m.l10nFile}.dart',
    );
    emitFlow(ctx, m);
    emitPackage(ctx, m);
    emitTests(ctx, m);
    if (m.skeleton != null) emitSkeleton(ctx, m);
    final unused = m.unusedProse;
    if (unused.isNotEmpty) {
      throw StateError(
        'options.prose has slot(s) no template uses: ${unused.join(', ')}',
      );
    }
  }
}
