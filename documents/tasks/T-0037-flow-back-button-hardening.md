# T-0037: Harden `McFlowBackButton` before the bricks copy it

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-26 `2943774`; Verifier PASS `251885f`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0037-flow-back-button-hardening` |
| Created | 2026-11-26 |
| Depends on | T-0036 |
| Related | F-0034, F-0035, T-0036 Merge section and verification report (R-1 to R-7), the TL `/code-review` at `cbadeb0`, P-075 |

## Goal
The P1-24 bricks will put `McFlowBackButton` on every generated page, so it has to be right in every navigation state. This task closes the gaps left after T-0036.

## TL decisions
1. **The flow publishes its outer route state.** `FeatureFlow` depends on its own outer `ModalRoute` (`ModalRoute.of(context)`) and exposes, through `FlowScope` (or a dedicated inherited widget), whether the outer navigator can pop. `updateShouldNotify` is true when that value changes, so the button rebuilds when routes below the flow change (a router `go`, a deep-link stack rebuild, `pushAndRemoveUntil`). The button never reads `outer.canPop()` without a dependency.
2. **Safe outside a flow.** On a first route that isn't inside a `FeatureFlow`, the button does a nullable scope lookup and falls back to the AppBar default logic. It never throws. The doc comment says it is safe on every page.
3. **Precedence on the flow root.** The order is: a local history entry (`route.willHandlePopInternally`), which shows a plain `BackButton` that pops the inner route; then a drawer (`DrawerButton`, as AppBar does); then the flow's outer back button. Document the order and test every case.
4. **flow_builder `didUpdateWidget`.** Schedule the same post-frame `canPop` recompute as `_listener` does (vendored patch change 5). Update the patch, `VENDORED.md`, the provenance check and the upstream draft. Rename the patch file so its name describes its content, for example `0001-navigation-channel-and-popscope.patch` (R-6).

## Acceptance criteria
- **T-0037-AC1:** Given a flow at the app root (no button), when the router rebuilds the stack as `[home, flow]` while keeping the same flow page key, then the back button appears without any other rebuild and pops back home. Given a pushed flow, when the routes below it are removed (`pushAndRemoveUntil`), then the button disappears. Both tests fail on T-0036's widget.
- **T-0037-AC2:** On a first route outside any `FeatureFlow`, the button builds without an error. It shows the drawer button if there is a drawer, and nothing otherwise.
- **T-0037-AC3:** Precedence on the flow root:
  - with a local history entry (for example `showBottomSheet` or a `LocalHistoryEntry`), back removes the entry and stays in the flow;
  - with a drawer on a pushed flow root, the drawer button shows;
  - otherwise the flow back button shows.

  The root button respects the outer route's `PopScope` (`maybePop`; a `pop` mutation must die, R-1). The always-mounted `PopScope` in flow_builder is pinned by a test (R-3).
- **T-0037-AC4:**
  - A `FlowBuilder` driven by `state:` from its parent, going from two pages back to one, accepts the next pop (patch change 5).
  - The "outside any route" test asserts on the widget's own render output, not on the test wrapper.
  - `T-0036-AC3_gates.sh` fails when a file it greps is missing.
  - Gates pass: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, provenance, coverage ≥ 90 % for `mc_feature_flow`, and the T-0032 byte-identity and cutoff checks. The mini_client e2e passes on a fresh simulator.

## Log
- 2026-11-26: Created and dispatched (TL) from the T-0036 review and Verifier residuals.
- 2026-11-26: Engineer: implemented the four TL decisions, patch change 5, tests, mutation script, gates, e2e (Engineer).

## Outcome
Branch `fleet/T-0037-flow-back-button-hardening`. Finding: [F-0036](../findings/F-0036-flow-back-button-hardening.md). Evidence: `documents/evidence/T-0037/engineer/`.

| AC | Evidence |
|---|---|
| T-0037-AC1 | `flow_back_button_test`: three "T-0037-AC1" tests (rebuilt stack `[home, flow]` under the same page key; pages `[home, flow]` to `[flow]`; `removeRoute` below a pushed flow). `AC1_negative_control.sh` puts T-0036's `flow_context.dart` and `feature_flow.dart` (b8f152c) back: all 3 FAIL (`AC1_negative_control.log`). |
| T-0037-AC2 | Three "T-0037-AC2" tests: first route with no drawer builds empty without an error, with a drawer shows `DrawerButton`, a pushed route outside a flow keeps the automatic back. |
| T-0037-AC3 | Six precedence tests (local history wins, also over a drawer, also at the app root; drawer on a pushed root; drawer on an app-root flow; otherwise the flow button; outer `PopScope` respected) plus the test pinning flow_builder's always-mounted `PopScope`. |
| T-0037-AC4 | `FlowBuilder` driven by `state:` and, separately, by a swapped `controller:`, accepts the next `popRoute`. The outside-any-route test asserts the widget's own `SizedBox` (under an `Align`). `AC4_gates_missing_file_negative.md` shows `T-0036-AC3_gates.sh` failing on a missing file (planted-phrase negative and positive control beside it). Gates: `T-0036-AC3_gates.md` PASS (test //..., lint, mc_arch_check, rules_fork check, format, l10n_check, provenance, coverage >= 90 %, T-0032 byte-identity and cutoff, mutations). e2e: `e2e/e2e-summary.md`, 3 targets PASS on `mc-T-0037-engineer-75705`, deleted (0 left). |

TL decisions, each killed by a mutation (`mutations_T-0037.log`, 15 mutations, all killed): D1 (2 mutations + never-reads-outerCanPop), D2 (2), D3 (4, including `pop` instead of `maybePop`), flow_builder (always-mounted scope, change 5 in both `didUpdateWidget` branches, change 4).

Notes for the Verifier and TL:
1. **Moved/changed tests:** `flow_kit_test` "T-0036-AC2 outside any route it is empty" now wraps in `Align` (not `SizedBox`) and asserts the widget's own `SizedBox` has zero size; stricter, not weaker. No test deleted, skipped, or `// ignore:` added.
2. **T-0036 `mutations.sh` superseded:** its old texts (`outer.canPop()`, `if (route.isFirst) {`) no longer exist. Its still-meaningful mutations are re-expressed in the T-0037 script; `T-0036-AC3_gates.sh` runs T-0033's and T-0037's scripts. The T-0036 file is untouched.
3. **Behaviour change (D3, intended):** a pushed flow root with a drawer now shows `DrawerButton`, not the back button.
4. `outerCanPop` is `!route.isFirst`, not `outer.canPop()` (which counts local history on the first route).
5. Provenance now also requires exactly one `*.patch` (negative in `provenance_extra_patch_negative.md`). Patch renamed to `0001-navigation-channel-and-popscope.patch`; `VENDORED.md` and the upstream draft updated.
6. New Bazel target `flow_back_button_test`; no pubspec or lock changes.

### Review round (after Verifier PASS `72dfd8c`)
Each item has a `T-0037-ACn` test in `flow_back_button_test` that fails without it (mutations R1 to R5 in `mutations.sh`; 21 mutations, all killed, `mutations_T-0037.log`).
1. **Open drawer** no longer turns the leading into a back arrow: the root branch needs `willHandlePopInternally && impliesAppBarDismissal`. Tests: drawer (opening, open, closing, closed) and `endDrawer`-only; the real `showBottomSheet` tests still give the plain back. (AC3, R1)
2. **`isFirst` pinned** by the VP8 scenario (app-root flow, outer route with a local history entry). Swapping to `route.canPop` or `Navigator.canPop()` is killed. (AC1, R2)
3. **Nested navigators:** `FlowScope.flowNavigatorObserver` / `isFlowNavigator`; the flow-root branch needs `route.navigator` to be the flow's own. Test: first route of a navigator nested in a flow page gets no flow back. (AC3, R3)
4. **Rebuild scope:** `_FlowScopeHost` holds the `ModalRoute` dependency; a dialog above the flow rebuilds no `FlowBuilder` (counted with `debugOnRebuildDirtyWidget`). (AC1, R4)
5. **`impliesAppBarDismissal` outside a flow** pinned: a history entry that does not imply dismissal gives no back; `route.canPop` alone is killed. (AC2, R5)
6. **`T-0036-AC3_gates.sh`:** only the `--output_base=` value is taken from `MC_BAZEL_STARTUP`; MISSING paths are relative to `GREP_ROOT`; no `MC_TASK=T-0036` export (each mutation script gets its own `MC_TASK`).
7. **`VENDORED.md`** Task row lists F-0036. F-0036 facts 10 to 13 added.
Gates: `T-0036-AC3_gates.md` PASS in full. e2e: 3 of 3 PASS on `mc-T-0037-engineer-2286`, deleted (0 left). No test deleted or skipped, no `// ignore:`. The D3 mutation texts in `mutations.sh` were updated for the new condition.

## Merge (TL)
- 2026-11-26: Verifier PASS `72dfd8c` (85/85; 15 of 18 Verifier mutations killed). The TL `/code-review` found an important bug the Verifier missed: an open drawer adds a `LocalHistoryEntry`, which turned the hamburger into a back arrow. It also flagged the nested-navigator, rebuild-scope and gate-script nits. Review round `4fa44d7` (21 mutations killed); re-verify PASS `251885f` (all 23 Verifier mutations killed; a dialog above the flow now causes 0 `FlowBuilder` rebuilds). The TL merged `--no-ff`; on the merge result `check` passed with 3 patches, 85/85 tests, lint was clean, `mc_arch_check` reported OK and provenance passed.
- Remaining: P-078 (a stale `outerCanPop` when the flow's own outer route holds a local history entry); nit: `isFlowNavigator` returns true when there is no observer. Only `FeatureFlow` builds a `FlowScope`, so this is safe in production. Document the observer as required when the kit is next touched.
