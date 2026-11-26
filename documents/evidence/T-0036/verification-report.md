# Verification report: T-0036 `McFlowBackButton`, a const flow back button that can't vanish

- **Verifier:** crew: Verifier (a fresh agent; not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0036-flow-back-button` @ **`2407e45`**, a detached checkout in the Verifier's own worktree
- **Simulator:** `mc-T-0036-verifier-48398`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it; afterwards `xcrun simctl list devices | grep -c mc-T-0036` gives 0
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier …`. Every test run that counts used `--nocache_test_results`. The server was shut down at the end
- **Re-verification at `cbadeb0`: PASS** (see [the last section](#re-verification-at-cbadeb0)). The round-1 verdict below is kept as history.
- **Verdict (round 1, `2407e45`): FAIL.** AC1 and AC3 pass. **AC2 fails**: nothing tests the `isFirst` condition (my mutation survives every test), and the widget does not "leave the AppBar's automatic back alone" on an inner page. It removes it. The T-0034 inner-page case was changed so that it no longer uses the widget, rather than kept. The fix is small (Issue 1).
  - Separately, Issue 2 (major, pre-existing, outside T-0036's scope) matters for the bricks. In the one scenario where the old button vanished, the new button is present but **dead**: tapping it never leaves the flow.

My evidence is in [`verifier/`](verifier/).

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates, as committed | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0036-verifier tool/checks/T-0035-AC4_gates.sh --role verifier` | **PASS**, all 8 gates ([T-0035-AC4_gates.md](verifier/T-0035-AC4_gates.md)): `test //...` (84 tests, with the touched packages uncached), lint, `mc_arch_check`, `rules_fork.sh check`, `dart format` (after `fvm flutter pub get --offline`), `l10n_check`, flow_builder provenance, and coverage. The script no longer has the "lock delta vs 6e7eaaf" gate (the line after the provenance gate is gone) |
| Touched packages, uncached (again, by hand) | `test --nocache_test_results //feature/characters/characters_list/... //utility/mc_feature_flow/... //third_party/flow_builder/...` | **9/9 PASSED** ([test_touched_uncached.log](verifier/test_touched_uncached.log)) |
| Coverage, my own parser | `coverage //utility/mc_feature_flow/... //feature/characters/characters_list/...`, then [my_coverage.py](verifier/my_coverage.py), written independently of `merge_lcov.py` | [coverage.txt](verifier/coverage.txt): mc_feature_flow **143/144 = 99.3 %** (misses `feature_flow.dart:214`); characters_list **155/155 = 100 %**. Every line of `McFlowBackButton.build` is hit. The files with no LCOV record contain only declarations (barrels, abstract classes, freezed declarations) |
| T-0032 byte identity | `tool/checks/T-0032-AC6_matches_build_runner.sh` | **PASS, 11 of 11 EQUAL**, from a fresh build_runner overlay ([report](verifier/T-0032-AC6_matches_build_runner.md)) |
| T-0032 cutoff | `tool/checks/T-0032-AC6_cutoff.sh` | **PASS** ([report](verifier/T-0032-AC6_cutoff.md)). The bloc's freezed action and shard ran; no aggregate, retrofit, combine or json spawn ran |
| L4 E2E | `tool/e2e_ios.sh --task T-0036 --role verifier` over a `prepare_pub_project.sh` copy, with my own [verifier_back_test.dart](verifier/verifier_back_test.dart) plus the committed `characters_journey_test.dart` | **2/2 PASS** ([e2e-summary](verifier/e2e/e2e-summary.md)) |

## Acceptance criteria
| AC | Mapped test(s) | Does the test really assert the AC? | Result |
|---|---|---|---|
| T-0036-AC1 | `flow_kit_test` "T-0036-AC1 the back button is present after the root page rebuilds under an inner page" | **Yes, for the failure it models, but that is narrower than the AC's wording.**<br>- **Engineer's negative control, re-run by me:** it puts `flowLeading()` back. AC1 FAILS with `Found 0 widgets with type "BackButton"`, and the AC2 tests still pass ([log](verifier/engineer_AC1_negative_control_rerun.log)).<br>- **My own control** ([run_probes.sh](verifier/run_probes.sh) `old`) restores origin/main's `flow_context.dart` and `characters_list_page.dart`. My V6 (the AC1 shape) FAILS on both android and iOS (0 back buttons). With the branch it PASSES (1).<br>- **My exemplar probe P1** ([characters_probe_test.dart](verifier/characters_probe_test.dart)): `characters_list` pushed from a home page, the preview open, the locale switched from en to de (the list rebuilds to "Figuren" under the preview), and the user taps the preview's back button. The list then has 1 back button, and one tap returns home. **But P1 also passes with the old `flowLeading()` code.** So does my kit-level V1/V1b/V5 (a const root rebuilt under the inner page, then the inner page popped by a tap or by the iOS edge swipe).<br>- **Why:** a *user* pop rebuilds the root page's subtree once (V5: 1 root build during the pop; the dirty-rebuild trace is in [probes_new.log](verifier/probes_new.log)). The stale `null` is recomputed. The bug only shows when the flow returns to its root through a **state change** (`controller.update`), which rebuilds nothing (V6: 0 builds).<br>- **Fairness (F-0035 facts 4 and 5):** the const root page is fair, because it is the exemplar's shape. Returning with `controller.update` is fair as well: it is the real API a bloc uses (`_flow.update(...)`) and the only way to reproduce the bug. But F-0035 says "both are real, but only the const-root case discriminates", and that is wrong. A const root plus a tap does **not** discriminate. Today's exemplar closes its preview only by a user pop, so in the exemplar the bug is latent, not live (Issue 3). The AC's literal scenario ("after popping the preview") passes with the old code, so no test of that literal scenario could fail with `flowLeading()`. The committed test reproduces the real defect instead, and fails without the fix | **PASS** (with Issues 2 and 3) |
| T-0036-AC2 | `flow_kit_test` group "T-0036-AC2 the flow root page can leave the flow": "present when pushed, and tapping it pops the flow", "absent when the flow is the root", "a page pushed inside the flow keeps the automatic back button, which pops that page only" | **Partly.**<br>- **Present, pops the flow, absent at the root:** asserted. My mutations M2 (drop `canPop`), M3b (pop the inner navigator), M4b (invert the root check) and M8 (read `canPop` from the inner navigator) are each killed by a T-0036 test ([log](verifier/mutations_McFlowBackButton.log)).<br>- **`isFirst` is not tested.** M1b (`isFlowRoot = ModalRoute.of(context) != null`, so any route counts as the root) **SURVIVES** every test in `mc_feature_flow`, `characters_list` and `//app/...`. M5 (`isCurrent`), M6 (`pop` instead of `maybePop`) and M7 (no route counts as root) also survive. M5 and M7 are close to equivalent; M6 means nothing pins that a `PopScope` is respected.<br>- **"On inner pages leaves the AppBar's automatic back alone": not met by the widget.** On main, the T-0034-AC5 inner-page test put the helper (`leading: context.flowLeading()`) on the detail page and asserted that the automatic back survives. The moved test removes it (`flow_kit_test.dart:636`, `AppBar(title: const Text('detail'))`). So the case is no longer "kept"; it no longer exercises the unit at all. My V3 puts `McFlowBackButton` back on the inner page: **0 back buttons** (with the old helper: 1). The widget replaces the automatic back with `SizedBox.shrink()`. The change is disclosed in the Outcome, and the scope asked for `SizedBox.shrink`, so this is a conflict between the spec and AC2's wording. It is not concealment.<br>- **No duplicate:** the tests never assert a count while the inner page is up (the test taps `find.byType(BackButton).last`). My V1 and my e2e show exactly one onstage back button on the inner page, so the behaviour is right but unasserted.<br>- **The moved assertions:** diffed against origin/main, every `expect`, `tap` and `pump` line is unchanged; only the names and the `leading:` lines differ | **FAIL** (Issue 1) |
| T-0036-AC3 | Engineer's [T-0036-AC3_gates.md](engineer/T-0036-AC3_gates.md) (output of `T-0035-AC4_gates.sh`); my greps and re-runs | **Yes, by checks; no artefact carries the AC ID except an evidence file name.**<br>- **No `flowLeading` / `McFlowNavigation`** in any code (`git grep` outside `documents/`: none).<br>- **Stale comments fixed:** `feature_flow.dart:66-67` now matches the code (always wrapped; core and Flutter delegates the host lacks are added); `api_client_test.dart:329` names the `AppConfig` trailing slash; `app/mini_client/BUILD.bazel:130-131` no longer says "skipped". F-0033 fact 3's stale last sentence is superseded by F-0035 fact 6 (crew may not edit an existing finding).<br>- **`mutations.sh`:** the log path is `MC_LOG`, default `/tmp/mc-T-0033-engineer-mutations.log`. I ran it with my own path: **9/9 killed** ([log](verifier/mutations_T-0033.log)). Push-to-go is killed by an **assertion** in `routes_test` (`Expected: '/characters'`, `Actual: '/characters/42'`), not by the compiler. I fed the committed `mutate()` a bare `go` rename that cannot compile: it reports `COMPILE ERROR (not killed by a test)` and sets `rc=1` ([mut_check_t0033.sh](verifier/mut_check_t0033.sh)).<br>- **`T-0035-AC4_gates.sh`** passes and no longer runs `T-0035-AC4_lock_delta.sh`. The lock-delta script now says it is a historical one-off.<br>- **Gates, coverage, byte identity and cutoff:** all PASS (above) | **PASS** (Issue 4: no `T-0036-AC3`-named check) |

**AC IDs in JUnit names** (fresh `flow_kit_test` `test.xml`): AC1 ×1, AC2 ×3. AC3 has no test or check script with its ID (Issue 4).

## Mutations and probes (mine)
Probes: [verifier_probe_test.dart](verifier/verifier_probe_test.dart) (kit level) and [characters_probe_test.dart](verifier/characters_probe_test.dart) (the exemplar). [run_probes.sh](verifier/run_probes.sh) runs them as temporary `flutter_test` targets ([ff_build_append.txt](verifier/ff_build_append.txt), [cl_build_append.txt](verifier/cl_build_append.txt)) against the branch (`new`) or origin/main's `flowLeading` code (`old`), then restores. Logs: [probes_new.log](verifier/probes_new.log), [probes_old.log](verifier/probes_old.log). Mutations: [mut_flow_back.sh](verifier/mut_flow_back.sh), with results in [mutations_McFlowBackButton.log](verifier/mutations_McFlowBackButton.log). M1, M3 and M4 first broke the analyzer or format (they were reported as COMPILE ERROR), so I rewrote them as M1b, M3b and M4b, which compile. After every run `git status` showed only this evidence.

| Probe | What | Branch | origin/main code |
|---|---|---|---|
| P1 | Exemplar: preview open, locale en→de, tap the preview's back, then tap the list's back | 1 button; home in one tap | **also 1**; home in one tap |
| V1 / V1b | Const root rebuilt under the inner page, then a tap / iOS swipe on the inner page | 1 button; home in one tap | **also 1** |
| V3 | `McFlowBackButton` placed on an inner page | **0** back buttons | 1 (helper returned null) |
| V4 | The root page replaced by a different first page | 1 | n/a (helper not used) |
| V5 | Root build count during a user pop (android, iOS) | 1 build, 1 button | 1 build, 1 button |
| V6 | Back to the root by `controller.update` (AC1 shape; android, iOS) | 1 button | **0 buttons** (the bug) |
| V7 | After a programmatic return to the root, tap the root back up to 6 times | **never leaves the flow**; a `PopScope(canPop: false)` is still mounted | button already gone |

| ID | Mutation of `McFlowBackButton` | Result |
|---|---|---|
| M1b | `isFirst` ignored (any route is the root) | **SURVIVED** |
| M2 | `!outer.canPop()` dropped | killed: `T-0036-AC2 … absent when the flow is the root` (and 3 `characters_list` goldens) |
| M3b | Pops the inner navigator | killed: `T-0036-AC2 present when pushed, and tapping it pops the flow` |
| M4b | Root check inverted | killed: T-0036-AC1, T-0036-AC2 present… |
| M5 | `isFirst` → `isCurrent` | survived (nearly equivalent: it rebuilds through the `ModalRoute` dependency) |
| M6 | `maybePop` → `pop` | survived (no test pins that `PopScope` is respected) |
| M7 | No route counts as root (`?? true`) | survived (no test outside a route) |
| M8 | `canPop` from the inner navigator | killed: T-0036-AC1, T-0036-AC2 present… |

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none deleted or skipped. The three T-0034-AC5 back-button tests were renamed `T-0036-AC2 …` with every `expect`, `tap` and `pump` line unchanged. **One setup change weakens coverage:** the inner page no longer uses the widget under test (`flow_kit_test.dart:636`). The Outcome discloses it (Issue 1).
- **Lint suppressions added:** none (the only `// ignore` match in the diff is the Outcome's sentence saying so).
- **Golden files updated:** none.
- **Unrelated changes:** none. Every file in `git diff origin/main...HEAD` is in the task's scope (the two in-scope extras are named in the Outcome).

## Visual acceptance
Screenshots from my e2e run on `mc-T-0036-verifier-48398` (the in-test `binding.takeScreenshot`, downscaled from 1206×2622 to 552×1200):

| Checkpoint | Screenshot | What is visible | Matches? |
|---|---|---|---|
| Home | [v01_home.png](verifier/e2e/v01_home.png) | "Mini Client" title, no back button, "Characters" and "Open placeholder 7" buttons | yes |
| List pushed from home | [v02_list_with_back_button.png](verifier/e2e/v02_list_with_back_button.png) | iOS back chevron at the top left, "Characters" title, grid of Amber Alchemist, Artisan, Bard, Beacon with bundled art | **yes: the back button shows** |
| Preview | [v03_preview.png](verifier/e2e/v03_preview.png) | One back chevron (the preview's), "Amber Alchemist" title, portrait art, "See full profile" | yes, no duplicate |
| List after the preview's back | [v04_list_after_preview.png](verifier/e2e/v04_list_after_preview.png) | Same as v02 (byte-identical): the chevron is still there | yes |
| After tapping the list's back | [v05_home_again.png](verifier/e2e/v05_home_again.png) | The home page again, no back button | **yes: one tap returns home** |

The committed `characters_journey_test` also passed (screenshots `01_home` to `04_full_profile_placeholder` in [e2e/](verifier/e2e/)).

## Issues found
1. **(major, AC2 FAIL) `isFirst` is untested, and the widget erases the automatic back on an inner page.** `utility/mc_feature_flow/lib/src/flow_context.dart:92-94`, `utility/mc_feature_flow/test/flow_kit_test.dart:604-661` (the inner page at `:636`).
   - Repro: run `verifier/mut_flow_back.sh round2`. M1b survives every test. Then run `verifier/run_probes.sh new`. V3 (the widget on an inner page) prints 0 back buttons.
   - Fix, TL's choice:
     - **(a) Preferred:** when the route is not the flow's first, render what the AppBar would have implied: `BackButton()` for the inner navigator, or `CloseButton()` for a fullscreen dialog, when `ModalRoute.of(context)?.impliesAppBarDismissal` is true. Then the widget is safe on every page, and the bricks can emit one shape everywhere. Put the widget back on the inner page in the AC2 test (as T-0034 had it) and assert exactly one onstage `BackButton` while the inner page is up. M1b would then fail "pops that page only".
     - **(b)** Keep `SizedBox.shrink()` by design, reword AC2, and add a test that pins the non-first branch, so M1b dies.
   - Either way, add a count assertion for "no duplicate". Optionally, add a `PopScope` test so that M6 dies.
2. **(major, pre-existing, outside T-0036's scope; a blocker for the bricks) After a programmatic return to the flow's root, the root back button is dead.** `third_party/flow_builder/lib/flow_builder.dart:98` and `:180-181`.
   - `_ConditionalPopScope(condition: _canPop)` is evaluated in the `setState` that `_listener` triggers. At that moment the inner navigator still holds the page being removed, so `_canPop` is true and `PopScope(canPop: false)` is mounted. Nothing rebuilds `FlowBuilder` after the navigator drops the page, so the scope stays.
   - Repro: V7 in `verifier_probe_test.dart`. After `controller.update((_) => const _S())`, the probe finds `PopScope canPop values: [false]`, and 6 taps on the root's `McFlowBackButton` never leave the flow. With origin/main's code the button is already gone in that state (V6/V7 `old`). The iOS edge swipe is disabled too, because the route's `PopScope` blocks it.
   - **This is exactly AC1's scenario.** T-0036 turns "no button" into "a button that does nothing". F-0035 fact 5 understates it ("the first outer pop is consumed"): every pop is blocked.
   - Any generated feature that closes an inner page from its bloc (a form that returns to the list on submit, say) will hit it. Suggest a P-item before P1-24, next to P-075: rebuild `FlowBuilder` (or recompute the scope) after page removal, or have `mc_feature_flow` own back handling.
3. **(minor, docs) F-0035 overstates the exemplar trigger and misattributes the test trap.** `documents/findings/F-0035-flow-back-button.md:5` (fact 1, "In the exemplar the trigger is a locale change with the preview open"), `:8` (fact 4, "only the const-root case discriminates") and `:9` (fact 5).
   - P1 shows that a locale change followed by a user pop keeps the button even with the old code. A user pop rebuilds the root, so only a state-driven return to the root shows the bug. The T-0034 report's R2-1 trigger sentence has the same overreach; its probe P6 used `controller.update`.
   - The AC1 test comment (`flow_kit_test.dart:705-714`) should say why it returns with `controller.update` and not with a tap.
4. **(minor, traceability) AC3 has no test or check named `T-0036-AC3`.** Only the evidence file `engineer/T-0036-AC3_gates.md` carries the ID; it was produced by `T-0035-AC4_gates.sh`, and the `flowLeading` and stale-comment checks are manual greps.
   - Suggest `tool/checks/T-0036-AC3_*.sh`, which greps that `flowLeading` / `McFlowNavigation` are absent from code and the three stale phrases are gone, then runs the gates (as T-0034-AC5 did).

## Notes for the Tech Lead
- Gates, coverage (99.3 % and 100 %), byte identity (11/11), cutoff, the T-0033 mutation script (9/9, with assertion kill and compile-error accounting) and the e2e (2/2) all pass. The FAIL is only Issue 1, which is a small change once you pick (a) or (b).
- Issue 2 is not this task's defect, but it decides whether the AC1 fix has any user-visible value. Today's exemplar never returns to its root through a state change, so it is not live yet. The bricks will make it live.
- The probe targets and mutation scripts are mine and committed only as evidence under `verifier/`. They are not wired into any BUILD file.
- I deleted the e2e scratch copy `/tmp/mc-T-0036-verifier-e2e.*` at the end.

---

## Re-verification at cbadeb0

- **Commit verified:** `fleet/T-0036-flow-back-button` @ **`cbadeb0`** (5 fix commits on top of my `00205cf`), a detached checkout in my own worktree. Output base `/tmp/mc-ob-T-0036-verifier`, shut down at the end
- **Simulator:** `mc-T-0036-verifier-66987`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it; afterwards `simctl` lists 0 `mc-T-0036` devices
- **Verdict: PASS.** All three ACs pass, and round 1's Issues 1 to 4 are fixed. What remains is four minor test gaps and three nits (R-1 to R-7 below), none of which makes an AC fail.

Evidence: [`verifier/rv/`](verifier/rv/) and [`verifier/e2e-rv/`](verifier/e2e-rv/). I wrote every probe and mutation script myself, apart from the committed `tool/checks/*` scripts and the engineer's `mutations.sh`. They ran as temporary BUILD targets or in-place edits that were reverted afterwards, and `git status` was clean after each run.

### The TL decisions, against the code
| Decision | Code | Matches? |
|---|---|---|
| (a) Off the flow root, render the AppBar's automatic leading | `flow_context.dart:95-118`. Off the root it gives `DrawerButton` when the Scaffold has a drawer, else `CloseButton` for a fullscreen `PageRoute` or `BackButton` when `impliesAppBarDismissal && canPop`, else empty. That is AppBar's own order. The root (`:102`) keeps the flow's `BackButton` (outer `maybePop`), then a `DrawerButton` when the flow is the app root, else empty | **yes** |
| Empty 56 px slot at the app root, accepted and documented | Widget doc comment (`flow_context.dart`, the "When the flow is the app's root" paragraph); F-0035 fact 3 | **yes** |
| Stale `PopScope` fixed as patch change 4 | `flow_builder.dart:174-180` (post-frame `setState` in `_listener`) and `:348-351` (always-mounted `PopScope(canPop: !condition)`); patch file, `VENDORED.md` change 4, F-0034 fact 9, upstream draft "Second issue" | **yes** |

### 1. AC2
- **The restored inner-page test** (`flow_kit_test.dart:604-669`) puts `leading: const McFlowBackButton()` on the inner page, as on main. It asserts `findsOneWidget` for `BackButton` while the inner page is up, and after the tap the detail is gone, `selected` is null and the flow is still open. My R1 agrees: 1 button, it pops only the inner page, and the root's button is back.
- **The `isFirst`-ignored mutation now dies.** My M1b (`route.isFirst` → `route.isActive`) and M1c (`isCurrent`) are each killed by 3 `T-0036-AC2` tests ([log](verifier/rv/mutations_McFlowBackButton_rv.log), driver [mut_flow_back_rv.sh](verifier/rv/mut_flow_back_rv.sh)).
- **My earlier mutations, re-expressed for the new code:**

  | Mutation | Result |
  |---|---|
  | M2 (root ignores `outer.canPop()`) | killed (AC2 "absent when root", 3 goldens) |
  | M3b (root pops the inner navigator) | killed (AC1, AC2) |
  | M7 (no route gives a `BackButton`) | killed |
  | M8 (`canPop` read from the inner navigator) | killed |
  | M9 (off-root drawer dropped) | killed |
  | M11 (fullscreen dialog gets `BackButton`) | killed on `flow_kit_test` by the `CloseButton` assertion (over `//utility/mc_feature_flow/...` the library's `unused_shown_name` warning stops the build first) |
  | M13 (off-root always empty) | killed |
  | M14 (off-root back pops the flow) | killed |
  | M6 (`maybePop` → `pop`) | **survives**, as in round 1 (R-1) |
  | M10 (drawer on the root when the flow is the app root) | **survives** (R-2) |
  | M12 (`impliesAppBarDismissal` ignored) | **survives**; it is equivalent in that branch, because off the first route both reduce to `hasActiveRouteBelow` |

- **My probes** ([rv_probe_test.dart](verifier/rv/rv_probe_test.dart), [log](verifier/rv/probes_head.log)):
  - **Drawer.** On a flow root that was pushed, the widget gives `BackButton`, not a drawer button. On a flow that is the app root, it gives `DrawerButton` with no back button. On an inner page, it gives `DrawerButton` (committed test).
  - **Fullscreen dialog** pushed on the flow's own navigator: `CloseButton` ×1, `BackButton` ×0. Tapping it closes only the dialog.
  - **Outside any route:** empty, no exception. On a route outside any flow (the app's home) it throws `FlutterError` from `FlowScope.read`. That is acceptable for a flow widget, but see R-5.
  - **The exemplar probe P1** (locale change with the preview open, then the user pops) still gives 1 button and goes home in one tap.

### 2. Dead button, patch change 4
- **My round-1 repro now passes.**
  - R2 is the return via `controller.update` (after a root rebuild under the inner page). The mounted `PopScope` now has `canPop: true`, and **one tap leaves the flow** (round 1: never, in 6 taps).
  - R3 is the same return followed by **one iOS edge swipe, which leaves the flow**.
  - Both committed AC1 tests now tap or swipe once and assert home.
- **Reverting patch change 4** with [run_rv.sh](verifier/rv/run_rv.sh). The edits were made in place on the vendored file and restored afterwards, standing in for the requested scratch copy ([both](verifier/rv/probes_nohunk4.log), [post-frame only](verifier/rv/probes_no_postframe.log), [scope only](verifier/rv/probes_no_alwaysscope.log)):

  | Reverted | T-0036-AC1 (button) | T-0036-AC1 (swipe) | R2 | R3 | R6 nested |
  |---|---|---|---|---|---|
  | both halves | **FAIL** | **FAIL** | FAIL (`[false]`, 6 taps) | FAIL | FAIL |
  | only the post-frame `setState` | **FAIL** | **FAIL** | FAIL | FAIL | FAIL |
  | only the always-mounted scope | pass | pass | pass | pass | pass |

  So the post-frame recompute is the fix. The always-mounted scope is a structural change, because stock swapped the widget and re-parented the whole navigator subtree. No test or probe depends on it (R-3).
- **The approach.** A post-frame `setState` that recomputes `_canPop` after the navigator has the new pages is minimal and correct.
  - It costs one extra `FlowBuilder` build per state update. That is cheap, because the pages are identical, and in-place updates pay it too.
  - Its window is one frame. My R4 (`x` then the root in one frame, tapped after 0, 1 or 2 frames) left the flow on the first tap in every case, with no exception. In practice the inner page's exit transition covers that frame anyway.
  - The `mounted` guard holds. R5 disposes the flow in the same frame as an update with the callback pending: no exception.
  - A `NavigatorObserver`-driven recompute would be exact, but it is not needed.
- **Regressions:**
  - **T-0022 VPROBE1-4**, spliced into `feature_flow_test` with [run_vprobes.sh](verifier/rv/run_vprobes.sh): **4/4 PASS** alongside the 10 committed T-0022 tests ([log](verifier/rv/vprobes_T-0022.log)).
  - **T-0035:** `flow_navigation_channel_test` and `framework_navigation_baseline_test` pass uncached. So do `links_after_flow_test` and the on-simulator `characters_link_after_flow_test`.
  - **Nested flows** (R6): the inner flow's root button pops the outer flow's nested page. After a state-driven return inside the inner flow, one tap shows the outer root with `outer.selected == null`, and the next tap goes home.
  - **R4b** (update to `x`, then tap the root back immediately): the flow leaves cleanly.
- **Provenance:**
  - `VENDORED.md` change 4 describes exactly the two hunks.
  - `T-0035-AC4_provenance.sh` passes: lib = archive + patch, 32 changed lines ([report](verifier/rv/rv_provenance_head.md)).
  - **Broken once** by restoring stock's `_ConditionalPopScope` line: **FAIL** "DIFFERS from the recorded patch" ([report](verifier/rv/rv_provenance_broken.md)). Restored.

### 3. Docs
- **F-0035:**
  - Fact 1 now says a user pop rebuilds the root, only a state-driven return keeps the button missing, and the bug is latent in today's exemplar.
  - Fact 4 now says the `controller.update` return is what discriminates.
  - Fact 5 now describes the stale `PopScope` and the masking re-parent rebuild.
  - The AC1 comments in `flow_kit_test.dart` (the `_RebuildingRoot` doc, the rebuild comment, and "One tap leaves the flow") are corrected.
- **F-0034 fact 9 and the upstream draft** ("Second issue") describe change 4 accurately.

### 4. AC3
- **`tool/checks/T-0036-AC3_gates.sh --role verifier`: PASS**, all 6 gates ([report](verifier/rv/T-0036-AC3_gates.md)): `T-0035-AC4_gates.sh`, T-0032 byte identity, cutoff, both mutation scripts, no `flowLeading`, and stale comments.
- **Negative, my own plants** in a scratch tree through `MC_GREP_ROOT`: a `context.flowLeading()` file, the stale `Empty:` doc line, `assertion above` and `skipped until T-0035`. Both grep gates **FAIL** and name each hit ([report](verifier/rv/AC3_negative_verifier.md)). The unplanted copy PASSES.
- **`mutations.sh` (T-0033):**
  - Without `MC_TASK` it stops with `MC_TASK: set MC_TASK (e.g. T-0036)`, rc 1.
  - With `MC_TASK=T-0036 MC_ROLE=verifier` it kills **9/9** ([log](verifier/rv/mutations_T-0033_rerun.log)).
  - Its committed `mutate()`, fed a non-test target, prints `ERROR (no failing test)` and sets rc 1 ([log](verifier/rv/mutations_sh_error_branch.log)). A missing target is reported as `COMPILE ERROR`, also rc 1.
- **The engineer's T-0036 `mutations.sh`**, run by me: **5/5 killed** ([log](verifier/rv/engineer_mutations_T-0036_rerun.log)). I checked the fullscreen-dialog kill separately: it is the `CloseButton` assertion, not the compiler.

### 5. Gates
| Gate | Result |
|---|---|
| Touched packages uncached (`characters_list`, `mc_feature_flow`, `third_party/flow_builder`, which has no tests of its own) | **9/9 PASSED** ([log](verifier/rv/rv_test_touched_uncached.log)); `test //...` 84/84 |
| lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, provenance, coverage ≥ 90 | PASS (inside `T-0036-AC3_gates.sh`) |
| Coverage, my parser | mc_feature_flow **147/148 = 99.3 %** (misses `feature_flow.dart:216`); characters_list **155/155 = 100 %** ([coverage](verifier/rv/rv_coverage.txt)) |
| T-0032 byte identity / cutoff | PASS, 11/11 EQUAL / PASS (inside the AC3 gates) |
| e2e on my simulator | **3/3 PASS**: my back-button journey, `characters_journey_test`, `characters_link_after_flow_test` ([summary](verifier/e2e-rv/e2e-summary.md)) |

**Screenshots I looked at:**
- [v02](verifier/e2e-rv/v02_list_with_back_button.png): the "Characters" grid with the iOS back chevron at the top left.
- [v03](verifier/e2e-rv/v03_preview.png): the Amber Alchemist preview with one chevron.
- [v04](verifier/e2e-rv/v04_list_after_preview.png): the grid again, chevron present.
- [v05](verifier/e2e-rv/v05_home_again.png): "Mini Client" home after one tap, no chevron.
- [06_link_after_flow](verifier/e2e-rv/06_link_after_flow.png): "Placeholder 42" from `miniclient://app/placeholder/42`, opened after the flow was shown, with a back chevron.

### 6. Integrity
- **The handoff now admits the round-1 weakening** ("Correction to the first handoff") and restores the test with a stricter assertion.
- **Against origin/main:**
  - The only changed test files are `flow_kit_test.dart` (+234 / −9) and `api_client_test.dart` (comment).
  - No `expect` line is removed; the only removed `testWidgets` lines are the three renames.
  - No `skip:` and no new `// ignore` in code. The two `ignore_for_file: avoid_print` hits are in my own probe files under `documents/evidence/`.
  - No golden changed.
- **All changed files are in scope:** `app/mini_client/BUILD.bazel`, the exemplar page, `mc_feature_flow` lib and test, `api_client_test`, vendored flow_builder (lib, patch, `VENDORED.md`), `tool/checks/T-0035-AC4_*`, the new `T-0036-AC3_gates.sh`, F-0034, F-0035, the upstream draft, the task file and evidence.

### Remaining issues (none blocking)
- **R-1 (minor, test gap, carried over):** nothing pins that the root button respects `PopScope` (`maybePop` → `pop` survives). Suggest a test with a `PopScope(canPop: false)` around the flow route.
- **R-2 (minor, test gap):** the `DrawerButton` branch for a flow that is the app root (`flow_context.dart:107`) is untested; my R7 shows it works.
- **R-3 (minor, test gap):** the always-mounted `PopScope` half of change 4 (`flow_builder.dart:348-351`) is not needed by any test or probe. It is justified (no re-parenting or full-page rebuilds when `canPop` flips), but a test that counts page builds across a push and pop would pin it.
- **R-4 (nit, design):** on a pushed flow root whose Scaffold has a drawer, the flow's `BackButton` wins and the drawer button is not shown. AppBar would show the drawer button there. This is consistent with decision (a), which covers off-root pages only, but undocumented.
- **R-5 (nit, docs):** on a route outside any `FeatureFlow`, the widget throws `FlutterError` (from `FlowScope.read`). The doc says "Safe on every page of a flow" (`flow_context.dart:76`), which is accurate; one line saying it needs a flow would help.
- **R-6 (nit, naming):** `third_party/flow_builder/0001-forward-pushRouteInformation.patch` now also carries the `PopScope` change, and the file name no longer describes it. `VENDORED.md` explains it.
- **R-7 (minor, test gap):** the engineer's AC3 negative (`engineer/AC3_negative_control.md`) planted only 2 of the 4 stale phrases; mine covers all 4 and every one is caught.
