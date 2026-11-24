# F-0023: `flutter_gen_l10n` equals `flutter gen-l10n` only after `dart format`; and other gen-l10n facts

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0025)
- **Type:** Spike result / Gotcha
- **Related:** T-0025-AC4, plan 03 §4.6, research `ai_rules_flutter.md` §6

## Summary
1. **Raw output is not byte-identical.** `fvm flutter gen-l10n` (3.47.7) runs `dart format` over what it writes. The Bazel rule does not (no format step). For `mc_l10n_core` (3 ARBs, 3 files) the content is the same; only whitespace and trailing commas differ (long lines, `switch` layout, trailing comma in `supportedLocales`).
2. **After `dart format --language-version=3.13` the Bazel output is byte-identical** to the CLI's, all 3 files. `tool/checks/T-0025-AC4_gen_l10n_parity.sh` proves this (evidence: `documents/evidence/T-0025/engineer/AC4_gen_l10n_parity.md`). T-0025-AC4 is therefore met "modulo formatting"; the Verifier and TL should accept or amend the AC wording (a format step in the rule is not available, plan 03 §4.6).
3. **The generated files are excluded from format and lint in practice.** The analysis aspect passed on the unformatted output (the lint rules the aspect applies do not flag it), and the files are not committed (`.gitignore` gets `**/lib/src/l10n/*_l10n*.dart`).
4. **File layout.** Per-locale files are named by the *language subtag* only: `en_XA` lands in `mc_l10n_core_l10n_en.dart` (class `McL10nCoreL10nEnXa` next to `McL10nCoreL10nEn`). Outputs: `mc_l10n_core_l10n.dart`, `_de.dart`, `_en.dart`.
5. **`template_arb_file` is a basename** (`mc_l10n_core_en.arb`), not a path; a path fails with "is not among `arbs`".
6. **The pub / IDE path.** `fvm flutter gen-l10n` aborts without `flutter: generate: true`, and `synthetic-package` in `l10n.yaml` only warns (dropped). With `generate: true` plus `l10n.yaml` (`output-dir: lib/src/l10n`), `fvm flutter pub get` writes the generated files beside the ARBs, so the barrel resolves and `fvm flutter analyze` is clean (without them: 2 `uri_does_not_exist`). The files are gitignored and excluded from the Bazel `srcs` glob (otherwise they would clash with the rule's outputs). The parity script runs the CLI in a throwaway copy with the repo's `.fvmrc` (pinned Flutter), `resolution: workspace` removed, stale generated files deleted, and checks the exit code.
7. **`flutter_localizations` and `intl`** are added to the workspace lock by listing them in a member pubspec (`flutter_localizations: sdk: flutter`, `intl: any`) and running `fvm flutter pub get`: intl 0.20.3. Bazel then exposes `@pub_deps//:flutter_localizations` and `@pub_deps//:intl`.
8. **`NumberFormat.currency(name: 'EUR')` prints the code** (`19,99 EUR`). Use `NumberFormat.simpleCurrency(name:)` for the symbol (`19,99 €`, `€19.99`). The de separator between amount and symbol is U+00A0, not a plain space.

## Implications
- P3 `mcgen` (plan 03 §4.6) should keep the l10n.yaml for IDE only and not emit `synthetic-package`.
- If a later task wants byte-identical raw output, the rule would need a format step (an upstream request to ai_rules_flutter), or the comparison stays "after format".
