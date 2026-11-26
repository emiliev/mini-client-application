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

- 2026-11-26: Verifier FAIL (AC2: `isFirst` untested, inner page lost its automatic back; defect 2: dead button after a state-driven return). Fix round (Engineer), see Outcome.

## Outcome
Branch `fleet/T-0036-flow-back-button`. Details: [F-0035](../findings/F-0035-flow-back-button.md), [F-0034](../findings/F-0034-flow-builder-navigation-channel.md) fact 9. Evidence: `documents/evidence/T-0036/engineer/`.

| AC | Evidence |
|---|---|
| T-0036-AC1 | `flow_kit_test`: "T-0036-AC1 the back button is present after the root page rebuilds under an inner page" (const root, rebuilt under the inner page, return by `controller.update`, **one tap leaves the flow**) and "T-0036-AC1 the iOS edge swipe leaves the flow after a state-driven return to the root". `AC1_negative_control.sh` puts the old `flowLeading()` back: the first FAILS (`Found 0 widgets with type "BackButton"`). Without flow_builder patch change 4 both fail (mutation "no canPop recompute", killed). |
| T-0036-AC2 | Restored T-0034-AC5 inner-page case, as on main, with the widget on the inner page: exactly ONE `BackButton` while it is up, and tapping it pops only that page. Plus "root present and pops the flow", "absent when the flow is the root", drawer gives `DrawerButton`, fullscreen dialog gives `CloseButton`, outside a route it is empty. Mutation "`isFirst` ignored" is killed. |
| T-0036-AC3 | `tool/checks/T-0036-AC3_gates.sh` (gates, T-0032 checks, no-`flowLeading` and stale-comment greps, both mutation scripts); negative control in `AC3_negative_control.md`. |

Fix-round notes (one line each):
1. **Widget** renders the `AppBar`'s own automatic leading off the flow root (`BackButton` / `CloseButton` / `DrawerButton`), empty only when none applies; safe on every page.
2. **Empty 56 px slot** at the app root: accepted, documented on the widget and in F-0035.
3. **Dead button** (Verifier defect 2): vendored flow_builder patch change 4 (a post-frame `canPop` recompute and an always-mounted `PopScope`); patch file, `VENDORED.md`, F-0034 fact 9 and the upstream draft updated; the evergreen provenance check passes; all T-0035 channel tests green.
4. **F-0035** facts 1, 4, 5 corrected; the AC1 test comment too. In the exemplar the bug is latent.
5. **`T-0036-AC3_gates.sh`** added, with a negative.
6. **`mutations.sh`** (T-0033's): `ERROR (no failing test)` sets `rc=1`; output base and log come from required `MC_TASK`/`MC_ROLE`. A T-0036 script `mutations.sh` has 5 mutations, all killed.
7. **Scope of edits (TL-approved):** `tool/checks/T-0035-AC4_gates.sh` no longer runs the lock-delta gate; `T-0035-AC4_lock_delta.sh` only got a "pre-merge only, pinned to 6e7eaaf" header; the `third_party/flow_builder` vendored copy, patch and `VENDORED.md`; `documents/upstream/...` draft; F-0034.

**Correction to the first handoff:** it said no test was weakened. That was wrong: the moved T-0034-AC5 inner-page test had its `leading:` removed from the inner page, so it no longer exercised the widget. It is restored as on main (widget on the inner page) with a stricter assertion (exactly one `BackButton`). No test deleted or skipped, no `// ignore:` added.
