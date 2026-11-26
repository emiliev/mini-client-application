# T-0040: `mc_ds_navigation`: app bars and tabs (U32, P1-12 subset)

| Field | Value |
|---|---|
| Status | In Verification |
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
- 2026-11-26: Engineer built `utility/mc_ds_navigation`, switched `characters_list` to `McAppBar`, and ran the gates, the mutations and the mini_client e2e. Handed off.

## Outcome
**Status:** Done, ready for verification. Branch `fleet/T-0040-ds-navigation`.

### Leading-slot design (and why)
`McAppBar.leading` is a plain `Widget?` slot, as `AppBar` has. The feature or brick passes `leading: const McFlowBackButton()`; the DS knows nothing about flows. A leading-builder contract was rejected: `McFlowBackButton` is already a self-deciding widget (it reads the route, the drawer and `FlowScope` itself on every build), so a builder adds an indirection with nothing to build from. With `leading: null` the bar falls back to `AppBar`'s automatic back, close or drawer button, so a page pushed inside a flow needs nothing. Layering: `mc_ds_navigation` depends on `mc_ds_theme`, `mc_ds_tokens` and `mc_ds_layout` only, so `mc_arch_check` stays satisfied and a utility never reaches the sibling that owns navigation state. `mc_arch_check` itself allows utility to utility edges, so AC3 is enforced by `tool/checks/T-0040-AC3_layering.sh` (F-0039 fact 5).

### What was built
- `McAppBar` (title as a header, `leading`, `actions`, `largeTitle`, `titleKey`). The large title is a fixed 64 px band, single line, ellipsis, text scale capped at 1.5 (a deliberate design choice, the band has a fixed height because `PreferredSizeWidget` cannot read the text scale).
- `McTabBar` and `McTab`: controlled (`currentIndex`, `onChanged`), tabs share the width when they fit and scroll when they do not, the selected tab is revealed, `tabBar` and `tab` semantics roles, 48 px high, at least 44 px wide.
- `McSectionHeader`: header title (wraps), optional action (44 px).
- `characters_list`: the list page uses `McAppBar(leading: const McFlowBackButton())`, the preview page uses `McAppBar(titleKey: ...)` with the automatic leading.

### AC to evidence
| AC | Evidence |
|---|---|
| AC1 | `utility/mc_ds_navigation/test/golden_test.dart`: 9 components x 4 themes x 2 scales = 72 goldens (plain, actions, large title, long title, long large title; tab bar 2 and 5 with one selected; section header with and without action), all looked at; samples in `documents/evidence/T-0040/engineer/goldens/navigation/`. No-overflow tests at 1x, 2x and 3x in `navigation_test.dart` ("T-0040-AC1 long titles at ...", "...stays inside its band at 3x", "...scrolled into view", ...) |
| AC2 | `navigation_test.dart` "T-0040-AC2 ...": app bar and section titles are headers, tabs have role `tab`, `selected` and their labels under a `tabBar` node whose children are exactly the tabs, every target at least 44 pt (8 targets counted), and `meetsGuideline(iOSTapTargetGuideline, labeledTapTargetGuideline, textContrastGuideline)` in all 4 themes |
| AC3 | `tool/checks/T-0040-AC3_layering.sh` ([report](../evidence/T-0040/engineer/ac3-layering.md)): `mc_arch_check` OK; no `mc_feature_flow` in the closure of the library or either test target; positive control (characters_list sees both packages); negative controls (a BUILD dep, a pubspec dep and a Dart import are each reported). `flow_scope_test.dart` "T-0040-AC3 the list page uses McAppBar with McFlowBackButton as leading". All T-0032 and T-0037 tests still pass |
| AC4 | `tool/checks/T-0040-AC4_gates.sh` ([report](../evidence/T-0040/engineer/ac4-gates.md)): `test //...` 87/87 (touched packages uncached), lint, `mc_arch_check`, `rules_fork.sh check`, format, l10n_check, provenance, the fixtures closure check (T-0031-AC6, scans every `utility/mc_*`), layering; coverage `mc_ds_navigation` 100 % (109/109), `characters_list` 100 %. e2e on a fresh simulator `mc-T-0040-engineer-<pid>` (deleted, 0 left): journey and link-after-flow PASS, [summary](../evidence/T-0040/engineer/mini_client/e2e-summary.md); [02_characters_list.png](../evidence/T-0040/engineer/mini_client/02_characters_list.png) shows the new bar with the flow back button |

Mutations ([script](../evidence/T-0040/engineer/mutations.sh), [log](../evidence/T-0040/engineer/mutations.log)): 12 mutations of the package, all killed by a failing test. The first run found two weak spots (the app bar title wrapper was redundant because `AppBar` already adds the header, so it was removed; the large-title scale cap was not asserted), both fixed.

### `characters_list` goldens that changed (4 of 4), all looked at
`characters_list_loaded`, `characters_list_error`, `characters_list_empty`, `character_preview`: only the app bar title changed, from the default regular weight to `McTypeScale.headline` (17 pt, semibold, `onSurface`). Same position, height and back arrow; the body is pixel-identical (before and after in `documents/evidence/T-0040/engineer/goldens/{before,after}/`).

### Test integrity
No test deleted, skipped or weakened; no `// ignore:`. One test added to `characters_list/test/flow_scope_test.dart` (AC3) and the four goldens above regenerated.

### Notes
- `pubspec.yaml` (root workspace) gained `utility/mc_ds_navigation`; `pubspec.lock` and `MODULE.bazel.lock` did not change. `origin/main` had no new commits at handoff, so no merge was needed.
- Decisions: none needing an ADR. Finding: [F-0039](../findings/F-0039-ds-navigation-semantics-and-layering.md).
- Follow-ups: add the rule "`mc_ds_*` never depends on `mc_feature_flow`" to `mc_arch_check` (F-0039 fact 5); the 5-tab bottom shell bar and breadcrumbs stay out of scope; Android tap-target guideline (48 dp) not checked (iOS first).
