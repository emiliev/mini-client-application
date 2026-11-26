# T-0040: `mc_ds_navigation`: app bars and tabs (U32, P1-12 subset)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0040-ds-navigation` |
| Created | 2026-11-26 |
| Depends on | T-0019 (DS foundation), T-0026 (golden harness), T-0037 (`McFlowBackButton`) |
| Related | plan 01 U32, P1-12; F-0014, F-0035, F-0036 |

## Goal
The DS navigation pieces every archetype uses, so features stop hand-rolling `AppBar`s. Features and bricks get one app bar that already does the right back behaviour.

## Scope
- **In:**
  - `utility/mc_ds_navigation` (U32), with three widgets:
    - `McAppBar` (title, actions, an optional large-title variant). Its default leading is `const McFlowBackButton()`, but the DS layer must not depend on `mc_feature_flow`. Solve this with a `leading` slot that the feature or brick fills, or with a small leading-builder contract. Choose one and justify it against the layering rules (`mc_arch_check`).
    - `McTabBar`.
    - `McSectionHeader`.
  - Goldens: 4 themes × 2 text scales, real fonts, through `mc_test_utils`.
  - `characters_list` switches to `McAppBar`. Its goldens may change; list them and look at them.
- **Out:** the bottom shell bar, which comes with the 5-tab shell later, and breadcrumbs.

## Acceptance criteria
- **T-0040-AC1:** Goldens exist for `McAppBar` (plain, with actions, large title, long title at 2×), `McTabBar` (2 and 5 tabs, selected and unselected) and `McSectionHeader`, in 4 themes × 2 text scales. A long title at 2× doesn't overflow.
- **T-0040-AC2:** Semantics: the `McAppBar` title is a header, tab items are selectable tabs with their labels, and every tap target is ≥ 44 pt. The Flutter `meetsGuideline` checks pass.
- **T-0040-AC3:** The layering holds: `mc_ds_navigation` doesn't depend on `mc_feature_flow` (`mc_arch_check`, plus a cquery check with a negative control). `characters_list` uses `McAppBar` with `McFlowBackButton` in its leading, and every T-0032 and T-0037 test still passes.
- **T-0040-AC4:** The package is registered, has ≥ 90 % coverage, and passes the fixtures check. The gates pass: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check` and format. The mini_client e2e passes on a fresh simulator, and the screenshot shows the new app bar.

## Log
- 2026-11-26: Created and dispatched (TL).
