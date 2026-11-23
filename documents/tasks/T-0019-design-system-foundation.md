# T-0019: Design-system foundation (P1-11)

| Field | Value |
|---|---|
| Status | In Progress |
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
_Pending._
