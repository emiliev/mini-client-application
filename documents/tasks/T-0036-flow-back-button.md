# T-0036: `McFlowBackButton`, a const flow back button that can't vanish (P-074, P-076)

| Field | Value |
|---|---|
| Status | In Verification |
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
- 2026-11-26: Engineer: implemented `McFlowBackButton`, removed `flowLeading`, fixed the stale comments and the mutation script, ran the gates (Engineer).

## Outcome
Branch `fleet/T-0036-flow-back-button`. Details: [F-0035](../findings/F-0035-flow-back-button.md). Evidence: `documents/evidence/T-0036/engineer/`.

| AC | Evidence |
|---|---|
| T-0036-AC1 | `flow_kit_test` "T-0036-AC1 the back button is present after the root page rebuilds under an inner page" (const root, rebuilt while an inner page is on top). Negative control `AC1_negative_control.sh` puts the old `flowLeading()` back: the test FAILS (`Found 0 widgets with type "BackButton"`), log in `AC1_negative_control.log`. |
| T-0036-AC2 | The three T-0034-AC5 tests, renamed `T-0036-AC2 ...` with every assertion kept: present and pops the flow when pushed, absent at the app's root, and an inner page keeps the automatic back button (that page's `AppBar` now has no `leading`, since the widget is for the root page only). |
| T-0036-AC3 | No `flowLeading` in code (only history in docs/evidence). `feature_flow.dart` doc, `api_client_test.dart` comment and `app/mini_client/BUILD.bazel` comment fixed. `mutations.sh` run: all 9 mutations killed by a test, push-to-go by `universe_wiring:routes_test` (`mutations_T-0033.log`). Gates: `T-0036-AC3_gates.md`; T-0032 byte-identity and cutoff: `T-0032-AC6_*.md`. |

Gates: test //..., lint, mc_arch_check, rules_fork.sh check, format, l10n_check, flow_builder provenance, coverage (mc_feature_flow 99.3 %, characters_list 100 %) all PASS. `T-0035-AC4_gates.sh` also lists its one-off "lock delta vs 6e7eaaf" gate, which is no longer run (removed in the follow-up commit); the gates script now PASSes.

Notes for the handoff: no test deleted, skipped or weakened, no `// ignore:` added. Edits outside the listed files: only `documents/evidence/T-0033/engineer/mutations.sh` (the mutation script, in scope) and the characters_list page comment.
