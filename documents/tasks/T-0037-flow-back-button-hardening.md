# T-0037: Harden `McFlowBackButton` before the bricks copy it

| Field | Value |
|---|---|
| Status | In Progress |
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
