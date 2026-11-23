# T-0019: Design-system foundation (P1-11)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-23; Verifier PASS `a18032a`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0019-design-system` (from `origin/main` `53c612d`+) |
| Created | 2026-11-23 |
| Depends on | T-0014 (toolchain, merged) |
| Related | [plan 01 §3, §6, P1-11](../plan/01-architecture-and-modules.md), Tide's `tide_design_system` ([research](../research/tide-miniclient/architecture-core.md) §4.6), F-0004 (golden fonts), [plan 05 golden rules](../plan/05-testing-and-bdd.md) |

## Goal
The visual foundation every Marvel screen uses (Tide's `tide_design_system`, split per plan 01): tokens, theme (light, dark, high-contrast), layout, buttons and feedback widgets, with real-font goldens on the iOS platform.

## Scope
- **In:**
  - `utility/mc_ds_tokens`, `utility/mc_ds_theme` (bundled **open-licensed** fonts; record the font licence), `utility/mc_ds_layout` (adaptive grid), `utility/mc_ds_buttons`, `utility/mc_ds_feedback` (including `McErrorView(onRetry)` and `Loading`).
  - Golden tests that load real fonts with `TargetPlatform.iOS` set (F-0004 gotcha 1).
  - `BUILD.bazel` per package (`flutter_library`, `flutter_test`). Add the packages to the root `pubspec.yaml` `workspace:` list (the only root-file change).
- **Out:** the `ds_catalog` app (P1-12), feature widgets.
- **Files / areas:** `utility/mc_ds_*/`, plus one root `pubspec.yaml` hunk.

## Acceptance criteria
- **T-0019-AC1:** Given each component × light/dark/high-contrast × text scale 1.0/2.0, then goldens match with **real fonts** (text readable, not Ahem boxes). A Verifier views a sample of golden PNGs.
- **T-0019-AC2:** Given `McErrorView(onRetry)`, when Retry is tapped, then the callback fires once and a semantics label exists.
- **T-0019-AC3:** Given widths 375 and 1024, then the adaptive grid shows 2 and 4 columns.
- **T-0019-AC4:** `tool/bazelw test //utility/mc_ds_tokens/... //utility/mc_ds_theme/... //utility/mc_ds_layout/... //utility/mc_ds_buttons/... //utility/mc_ds_feedback/...` passes, and `build --config=lint` is clean. Goldens are deterministic across 2 runs.

## Log
- 2026-11-23: Created and dispatched (app work, in parallel with T-0017).

## Outcome
Implemented 5 packages under `utility/` (tokens, theme, layout, buttons, feedback); root `pubspec.yaml` gained 5 `workspace:` lines.

| AC | Tests | Result |
|---|---|---|
| AC1 | `tokens_test`, `theme_test`, `buttons_test`, `feedback_test` (names contain `T-0019-AC1`); `golden_test` in theme, layout, buttons, feedback: 56 goldens = 7 components (theme_sheet, adaptive_grid_375, adaptive_grid_1024, buttons, loading, error_view, empty_view) x light/dark/highContrast/highContrastDark x text scale 1.0/2.0 | pass; real Inter text and MaterialIcons visible |
| AC2 | `feedback_test`: Retry fires once; semantics label `Error: ...` exists | pass |
| AC3 | `layout_test`: 2 columns at 375, 4 at 1024 (plus breakpoint edges); goldens at both widths | pass |
| AC4 | `bazel test` on the 5 package globs: 9/9 pass; `build --config=lint //utility/...` clean; `dart format` clean; goldens byte-identical over 2 regenerations | pass |

Font: Inter (SIL OFL 1.1), licence in `utility/mc_ds_theme/assets/fonts/OFL.txt`, recorded in the package README. Finding: F-0014. Evidence: `documents/evidence/T-0019/engineer/`.

Notes: loading/error strings are parameters with English defaults (no `mc_l10n_core` yet). The golden harness lives in the testonly package `utility/mc_ds_testing` (6th workspace entry) until `mc_test_utils` exists. Package visibility is public until the P3-06 package_group exists.

Review round 1 (code-review) fixes: font family now `packages/mc_ds_theme/Inter` (test `fonts_test`), public visibility, dark high-contrast palette/theme/goldens, harness split out of `mc_ds_theme`, plus the nits (icon-button semantics, unbounded widths, palette lerp, icons discovery, test rename, F-0013 -> F-0014). Evidence: `documents/evidence/T-0019/engineer/round2-*.txt`. No tests deleted or weakened.

## Merge (TL)
- 2026-11-23: `/code-review` found 4 important issues (Inter font name, visibility, dark high-contrast, `flutter_test` in the production package), fixed in `e11da43`. The first Verifier pass FAILED (AC2: `McIconButton` label and tap action on separate nodes), fixed in `19705dc`. Re-verify PASS `a18032a`. The rebase onto main brought in the T-0017 lints, so mechanical lint fixes landed in `1f71377`; the TL reviewed that diff (imports and braces only, no goldens changed). The TL merged `--no-ff`; on the merge result `test --nocache_test_results //...` passed 15/15, lint was clean and `mc_arch_check` reported OK.
- Follow-ups: P-031 (Inter in the Bazel app bundle), P-032 (restrict `//visibility:public` to the P3-06 package_group), P-033 (move `mc_ds_testing` into `mc_test_utils`).
