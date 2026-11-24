# T-0025: `mc_l10n_core` + `mc_formatters`, plus the per-package l10n check (P1-13)

| Field | Value |
|---|---|
| Status | In Progress |
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

## Outcome
_Pending._
