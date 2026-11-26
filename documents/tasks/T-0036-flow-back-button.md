# T-0036: `McFlowBackButton`, a const flow back button that can't vanish (P-074, P-076)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0036-flow-back-button` |
| Created | 2026-11-26 |
| Depends on | T-0034 (`context.flowLeading()`), T-0033 |
| Related | P-074, P-076, F-0033, T-0034 Verifier report (re-verification defect 1) |

## Goal
Before the P1-24 bricks copy the exemplar, change the flow root's back button from a value computed once in the caller's `build` (`context.flowLeading()`) to a widget that decides for itself every time it builds. Today the button can disappear when the root page rebuilds while an inner page is on top, for example after a locale change with the preview open.

## Scope
- **In:**
  - `utility/mc_feature_flow`: add `const McFlowBackButton()`. In its own `build`, it shows a `BackButton` that pops the flow when its route is the flow's first route and the outer navigator can pop; otherwise it shows nothing (`SizedBox.shrink`).
  - Deprecate or remove `context.flowLeading()`. There's only one caller, so prefer removing it.
  - `characters_list` uses `leading: const McFlowBackButton()`.
  - Fix the stale doc at `feature_flow.dart:66` (the flow is always wrapped in `Localizations.override`).
  - Fix the stale "assertion above" comment in `api_client_test.dart`.
  - P-076: the stale "skipped until T-0035" comment at `app/mini_client/BUILD.bazel:130`. Also `mutations.sh` in `tool/checks`/evidence: give the log path a task/role name and make the push-to-go mutation fail a test, not compilation.
- **Out:** everything else.

## Acceptance criteria
- **T-0036-AC1:** Given the characters list pushed from home with the preview open, when the root page rebuilds (for example, a locale change), then after popping the preview the list's back button is present. The test fails with `context.flowLeading()` (show it).
- **T-0036-AC2:** `McFlowBackButton` is present when the flow is pushed, pops the flow when tapped, is absent at the app's root, and on inner pages leaves the AppBar's automatic back alone (no duplicate button). These are the T-0034-AC5 back-button cases, moved over or kept.
- **T-0036-AC3:** No `flowLeading` call remains. The stale comments are fixed. `mutations.sh` uses a task-named log path, and its push-to-go mutation is killed by a test assertion. Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format, coverage ≥ 90 % for `mc_feature_flow`, and the T-0032 byte-identity and cutoff checks.

## Log
- 2026-11-26: Created and dispatched (TL).
