# T-0025: `mc_l10n_core` + `mc_formatters`, plus the per-package l10n check (P1-13)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-24; Verifier PASS `bd505d6`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0025-l10n` |
| Created | 2026-11-24 |
| Depends on | T-0017 |
| Related | [plan 01 P1-13, D4b](../plan/01-architecture-and-modules.md), [plan 03 gen-l10n](../plan/03-bazel-integration.md), R24 (pseudo-locale), `flutter_gen_l10n` rule |

## Goal
Localisation, which Tide's articles don't cover (D4b). Common strings and formatters, and the per-package ARB plus `flutter_gen_l10n` pattern every feature will copy.

## Scope
- **In:**
  - `utility/mc_l10n_core`: common strings (OK, Cancel, Retry, errors) in `en` and `de`, plus the pseudo-locale `en_XA` for l10n tests (filtered out of release, R24). Generated with the `flutter_gen_l10n` rule from ARB files; the delegate is exposed.
  - `utility/mc_formatters`: `Money`, dates, compact numbers; locale-aware via `intl`.
  - `tool/l10n_check`: verifies every package's ARB set has every supported locale and no missing keys.
- **Out:** feature strings.

## Acceptance criteria
- **T-0025-AC1:** Given locale `de`, then the common strings resolve in German. Given `en_XA`, then the pseudo-localised strings render.
- **T-0025-AC2:** Given `Money(1999, EUR)` in `de`, then it formats as `19,99 €` (and `€19.99` in `en`).
- **T-0025-AC3:** Given a package ARB set missing a locale or a key, when the l10n check runs, then it fails naming the locale or key.
- **T-0025-AC4:** The `flutter_gen_l10n` output for `mc_l10n_core` equals `fvm flutter gen-l10n`'s output for the same inputs (byte-identical). `test //...`, lint and `mc_arch_check` pass.

## Log
- 2026-11-24: Created and dispatched.
- 2026-11-24: Engineer implemented; handed to Verifier.
- 2026-11-24: Review fixes: `l10n_check` no longer follows symlinks and skips `bazel-*`/`external`/caches (keyed by package path, `--locales=`, unknown flags rejected); `workspace_gate_test` runs it as a Bazel gate; parity script pins Flutter via `.fvmrc` and checks the exit code; pub/IDE path works (`flutter: generate: true`, F-0023); `formatDateTime` uses `add_jm()`; `mcSupportedLocales()` documented as the release-filtered list (R24); finding renumbered F-0023.

## Outcome
Engineer handoff (branch `fleet/T-0025-l10n`).

- `utility/mc_l10n_core`: ARBs `en`, `de`, `en_XA` in `lib/src/l10n/`, `flutter_gen_l10n` target `_l10n` (class `McL10nCoreL10n`), `mcLocalizationsDelegates`, `mcSupportedLocales({includePseudo})` (en_XA only for tests, R24), `l10n.yaml` for IDE/CLI baseline.
- `utility/mc_formatters` (pure Dart, intl): `Money(minorUnits, Currency)`, `formatMoney/Date/DateTime/Compact/Number`, `initializeFormatters()`. Does not depend on `mc_l10n_core` (plan lists it; nothing needs it yet).
- `tool/l10n_check` (`bazelw run //tool/l10n_check:bin [root] [--locales en,de]`): required locales en+de; reports missing locale, missing/unknown key, `@@locale` mismatch, naming the package, locale and key.
- Root: 3 workspace members in `pubspec.yaml`, `pubspec.lock` (intl 0.20.3, flutter_localizations), `MODULE.bazel.lock`, `.gitignore` (+ `**/lib/src/l10n/*_l10n*.dart`).

| AC | Tests |
|---|---|
| AC1 | `//utility/mc_l10n_core:l10n_test` (4 tests, `T-0025-AC1 ...`) |
| AC2 | `//utility/mc_formatters:formatters_test` (`T-0025-AC2 ...`) |
| AC3 | `//tool/l10n_check:l10n_check_test` (`T-0025-AC3 ...`); repo run: `l10n_check: OK` |
| AC4 | `tool/checks/T-0025-AC4_gen_l10n_parity.sh`: **identical after `dart format`, raw differs in whitespace only** (F-0023). AC wording needs TL/PO acceptance. |

Gates: `test //...` 42/42, `build --config=lint //...`, `mc_arch_check`, `l10n_check` all PASS (`documents/evidence/T-0025/engineer/`). Deviations: de money uses U+00A0 between amount and symbol (intl's output); `formatDate` de is `24. Nov. 2026`.

## Merge (TL)
- 2026-11-24: **AC4 amended by the TL:** parity is byte-identical after `dart format` (F-0023, upstream P-046). Verifier PASS `7b8e3b1`. `/code-review` found 4 important issues (`l10n_check` following symlinks into the execroot, the parity script not pinning Flutter, the IDE/pub path broken, `formatDateTime` 24h-only), fixed in `4ccf962` along with the Verifier minors (`mcSupportedLocales()` release-filtered; `//tool/l10n_check:workspace_gate_test`). Re-verify PASS `bd505d6`. The TL merged `--no-ff`; on the merge result tests passed 43/43, lint was clean and `mc_arch_check` reported OK.
- Follow-ups: P-047 (hide or rename the generated `supportedLocales` that includes `en_XA`; the workspace gate skips packages not listed in its data).
