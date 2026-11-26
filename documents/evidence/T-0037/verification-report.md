# Verification report — T-0037: Harden `McFlowBackButton` before the bricks copy it

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0037-flow-back-button-hardening` @ `f2b641a`
- **Simulator:** `mc-T-0037-verifier-82301`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it, and afterwards `xcrun simctl list devices | grep -c mc-T-0037-verifier` gives 0. The scratch pub copy `/tmp/mc-T-0037-verifier-e2e` is deleted too.
- **Bazel:** `--output_base=/tmp/mc-ob-T-0037-verifier`, shut down at the end.
- **Verdict: PASS.** All four ACs pass. Below are 2 minor residuals and 3 nits, none of which fails an AC.

Evidence is in [`verifier/`](verifier/). I wrote every probe and mutation script there myself. The only scripts I ran that I didn't write are the committed `tool/checks/*` scripts and the engineer's committed `AC1_negative_control.sh` and `mutations.sh`. Probes ran as an untracked test file, removed afterwards. Mutations were in-place edits restored from a backup, and `git status` was clean after each run.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates in one | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0037-verifier tool/checks/T-0036-AC3_gates.sh --role verifier` | **PASS**: gates, T-0032 byte identity, T-0032 cutoff, mutation scripts (T-0033's and T-0037's), no `flowLeading`, stale comments |
| Tests | `T-0035-AC4_gates.sh` (`test --nocache_test_results` over `characters_list/...`, `mc_feature_flow/...` and `third_party/flow_builder/...`, then `test //...`) | **PASS**, 85/85 targets (84 + the new `flow_back_button_test`). A separate uncached run of `mc_feature_flow/...`: 5/5 ([report](verifier/T-0035-AC4_gates.md)) |
| L0 lint / arch / fork / format / l10n | same script: `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format --set-exit-if-changed`, `l10n_check` | all **PASS** |
| Provenance | `tool/checks/T-0035-AC4_provenance.sh` | **PASS**: sha256 matches, lib/ = archive + `0001-navigation-channel-and-popscope.patch` (39 changed lines), LICENSE byte-equal, no hosted references ([report](verifier/prov_positive.md)) |
| Coverage, gate parser | `merge_lcov.py` | `mc_feature_flow` 152/153 = **99.3 %**; `characters_list` 155/155 = **100 %** |
| Coverage, my parser | [vcov.py](verifier/vcov.py) over the same `testlogs/**/coverage.dat` | `mc_feature_flow` **152/153 = 99.3 %** (`flow_context.dart` 27/27, `feature_flow.dart` 118/119). `characters_list` 195/197 = 99.0 %: my parser also counts the gen-l10n `characters_list_l10n.dart` (16/18), which `merge_lcov.py` excludes as generated ([output](verifier/coverage_own_parser.txt)) |
| T-0032 byte identity | `tool/checks/T-0032-AC6_matches_build_runner.sh` | **PASS, 11/11 EQUAL** ([report](verifier/T-0032-AC6_matches_build_runner.md)) |
| T-0032 cutoff | `tool/checks/T-0032-AC6_cutoff.sh` | **PASS** ([report](verifier/T-0032-AC6_cutoff.md)) |
| T-0037 mutation script | `MC_TASK=T-0037 MC_ROLE=verifier documents/evidence/T-0037/engineer/mutations.sh` | **15/15 killed** ([log](verifier/eng_mutations_T-0037_verifier.log)) |
| My mutations | [vmut.sh](verifier/vmut.sh) | 18 mutants: **15 killed, 3 survive** (V9, V10, V19, see the Issues; [log](verifier/vmut_results.log)) |
| L4 E2E | `tool/e2e_ios.sh --task T-0037 --role verifier` over a `prepare_pub_project.sh` copy: my [verifier_back_t0037_test.dart](verifier/verifier_back_t0037_test.dart) and the three committed targets | **4/4 PASS** ([summary](verifier/e2e/e2e-summary.md)) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0037-AC1 | Flow at root, then the stack is rebuilt as `[home, flow]` under the same key: the button appears and pops home. A pushed flow loses the routes below it: the button goes. Both tests fail on T-0036's widget | `flow_back_button_test`: three "T-0037-AC1" tests (rebuilt page stack; `[home, flow]` → `[flow]`; `removeRoute`) | **Yes.**<br>- **Engineer's negative control, re-run:** all 3 FAIL on b8f152c's widget ([log](verifier/eng_ac1_neg.log)).<br>- **My own control** ([own_neg_control.sh](verifier/own_neg_control.sh)) keeps the T-0037 `FlowScope`/`FeatureFlow` and puts back only T-0036's button body. All 3 AC1 tests FAIL ([log](verifier/own_negative_control_T0036_button.log)).<br>- **My real-`GoRouter` probes** ([verifier_probe_test.dart](verifier/verifier_probe_test.dart)), each run with the same flow instance and with a new flow instance on every build:<br>&nbsp;&nbsp;- VP1 `go('/list')` from `/characters`, where both pages have the key `flow`: the same `FeatureFlow` state, **the root page is not rebuilt** (build count unchanged), the button appears, and one tap shows home.<br>&nbsp;&nbsp;- VP2 `go` the other way: the button goes.<br>&nbsp;&nbsp;- VP3 and VP4 do the same through a real `flutter/navigation` `pushRouteInformation` deep link, which passes through the vendored flow_builder handler.<br>&nbsp;&nbsp;- VP5 `removeRouteBelow(flow)`: the button goes.<br>&nbsp;&nbsp;- VP6 `pushAndRemoveUntil(flow, (_) => false)`: no button after the transition.<br>&nbsp;&nbsp;- VP7 `replaceRouteBelow`: the button stays and pops to the new route.<br>All pass on HEAD ([log](verifier/probes_on_head.log)). VP1–VP5 **fail on T-0036's widget** ([log](verifier/probes_on_T0036_widget.log)).<br>- **Mutations:** V11 (`maybeOf` with no dependency), V16 (`updateShouldNotify` false) and V17 (`outerCanPop` always true) are each killed by the AC1 tests.<br>- **`!isFirst` vs "the outer navigator can pop":** see the judgement below and Issue 1 | **PASS** |
| T-0037-AC2 | First route, no `FeatureFlow`: builds without error; a drawer gives `DrawerButton`, otherwise nothing. Pushed route: automatic back | Three "T-0037-AC2" tests | **Yes.** The empty case asserts no exception, no Back/Drawer button, and that the widget's own `SizedBox` has no child.<br>- **My probes:** VP15 (empty, no `IconButton` under the widget), VP16 (`DrawerButton`, and tapping it opens the drawer), VP17 (pushed route: `BackButton` pops it; fullscreen dialog: `CloseButton`).<br>- **Mutations:** V15 (drawer ignored on a first route) killed; the engineer's D2 (`FlowScope.of`, which throws) killed.<br>- On T-0036's button, the two first-route tests FAIL, because `FlowScope.read` throws | **PASS** |
| T-0037-AC3 | Order on the flow root: local history entry, then drawer, then outer `maybePop`, then nothing. Respects the outer `PopScope`. The always-mounted `PopScope` is pinned | Seven "T-0037-AC3" tests | **Yes.**<br>- **Every permutation of the order dies:** V1–V5 are the 5 non-identity orders of (local, drawer, outer). Each is killed by "a local history entry wins" and/or "a drawer on a pushed flow root".<br>- **Other order mutants:** V6 (local step removed), V7 (the local entry gets the outer button) and V18 (local only when the flow can be left) are killed.<br>- **`maybePop` → `pop`:** killed by the `PopScope(canPop: false)` test, both by V8 and by the engineer's D3.<br>- **Pin test:** V13 (stock conditional `PopScope`) is killed by "flow_builder keeps one PopScope mounted".<br>- **Real `showBottomSheet`** (committed test plus my VP14): back closes the sheet and stays in the flow.<br>- **Real `LocalHistoryEntry`** (my VP11–VP13): on a pushed root, back removes the entry (`onRemove` called once), the flow stays, and the next tap leaves. With a drawer, the entry wins over `DrawerButton`. On an app-root flow, `BackButton` appears and removing the entry hides it again | **PASS** |
| T-0037-AC4 | Change 5 (`state:` / `controller:` shrink accepts the next pop); the "outside any route" test asserts on the widget's own output; the gates script fails on a missing file; the gates pass; e2e | Three "T-0037-AC4" tests, `T-0036-AC3_gates.sh`, provenance, e2e | **Yes.**<br>- **Change 5:** V14 reverts only change 5 (both `didUpdateWidget` lines). The `state:` test, the `controller:` test and the `PopScope` pin test (which also drives `state:`) all FAIL. The engineer's two single-branch mutants are killed too.<br>- **Outside any route:** the test uses `Align`, so the box is the widget's own `SizedBox` (`Size.zero`, no `IconButton`).<br>- **Gates script, my negatives** (`MC_ONLY_GREPS=1 MC_GREP_ROOT=<copy>`): with all 3 files present it passes; with `app/mini_client/BUILD.bazel` missing, or `api_client_test.dart` renamed, it **FAILS** with `MISSING (cannot check …)` ([renamed](verifier/AC4_gates_renamed_file_negative.md)).<br>- **Provenance negatives** ([prov_neg.sh](verifier/prov_neg.sh), [log](verifier/prov_negatives.log)): an extra `*.patch`, the patch renamed back to the old name, lib/ without change 5, the patch without one change-5 line, and no patch at all **each FAIL**.<br>- **`VENDORED.md` changes 1–5 vs the patch hunks vs lib/:** agree, and provenance proves the patch = lib/ − archive.<br>- **Gates and e2e:** all pass (above) | **PASS** |

### Is `outerCanPop = !route.isFirst` the right signal?
The TL wrote "whether the outer navigator can pop". `!isFirst` and `outer.canPop()` differ in two cases my probes show:
- **VP8:** the flow's own outer route holds a local history entry.
- **VP9:** a dialog route sits above an app-root flow in the outer navigator.

In both cases `canPop()` is true, but there is no route below the flow to go back to. A button there would only remove the entry or the dialog, not leave the flow. `!route.isFirst` equals Flutter's (protected) `hasActiveRouteBelow` when the route is installed, and it is what "the flow can be left" means. **I agree with `isFirst`**, and F-0036 fact 2 documents the reason. But no committed test pins the choice (Issue 1).

## Regressions
- **T-0022 VPROBE1-4:** I copied `feature_flow_test.dart` with the committed T-0022 probe fragment spliced in, and ran it with `fvm flutter test`. **14/14 PASS**: the 10 committed tests and VPROBE1-4 ([log](verifier/vprobes.log)).
- **T-0035:** `flow_navigation_channel_test` and `framework_navigation_baseline_test` PASS uncached.
- **T-0036:** the AC1/AC2 tests in `flow_kit_test` PASS uncached.
- **`characters_list` BDD**, including "Going back from the preview keeps the list where I left it": PASS, uncached in the gates run.
- **`//app/mini_client:links_after_flow_test`:** PASS in `test //...` (rebuilt, since `mc_feature_flow` changed).
- **E2E:** 4/4 PASS. The committed journey, deep-link and link-after-flow targets, plus mine.

## Test-integrity audit
- **Every AC has tests named for it:** AC1 ×3, AC2 ×3, AC3 ×7, AC4 ×3 in `flow_back_button_test`.
- **The one changed T-0036 test** (`flow_kit_test` "T-0036-AC2 outside any route it is empty") is **stricter**:
  - Old: `SizedBox(child: McFlowBackButton())` plus `find.byType(SizedBox) findsWidgets`, which the wrapper alone satisfies.
  - New: an `Align` wrapper, exactly one `SizedBox` under the widget, and `Size.zero`.
- **The superseded T-0036 mutation script:** all 5 of its mutations are re-expressed in the T-0037 script, and each is still killed:
  - isFirst ignored
  - the root ignores whether it can pop → "never reads outerCanPop"
  - no DrawerButton off the root → D2
  - fullscreen dialog
  - change 4 recompute

  They now run against both test targets, not only `flow_kit_test`. Nothing is lost. The T-0036 file is unchanged.
- **Tests deleted, skipped or weakened:** none. No `skip:`.
- **Lint suppressions added:** none. The diff adds no `// ignore:`; the only one in `flow_builder.dart` is upstream's.
- **Golden files updated:** none.
- **Diff review against `origin/main`:** code changes only in `flow_context.dart`, `feature_flow.dart`, the vendored `flow_builder.dart` and the patch, the two check scripts, and the new BUILD target. Docs: the task file, the new F-0036, `VENDORED.md` and the upstream draft (the draft update was asked for by TL decision 4). STATUS, BOARD, journal and indexes are untouched. Old-patch-name references remain only in historical evidence and reports.

## Visual acceptance (UI tasks)
Screenshots from the in-test `binding.takeScreenshot` on `mc-T-0037-verifier-82301`, downscaled from 1206×2622 to 552×1200:

| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Home | [v01_home.png](verifier/e2e/v01_home.png) | "Mini Client" title, no back button, "Characters" and "Open placeholder 7" buttons | yes |
| List pushed from home | [v02_list_with_back.png](verifier/e2e/v02_list_with_back.png) | iOS back chevron at the top left, "Characters" title, grid of Amber Alchemist/Artisan/Bard/Beacon with art | **yes: the chevron shows** |
| Preview | [v03_preview.png](verifier/e2e/v03_preview.png) | One chevron, "Amber Alchemist", portrait, "See full profile" | yes (test asserts one onstage `BackButton`) |
| List after the preview's back | [v04_list_after_preview.png](verifier/e2e/v04_list_after_preview.png) | Same as v02: the chevron is still there | yes |
| After one tap on the list's back | [v05_home_again.png](verifier/e2e/v05_home_again.png) | Home again, no back button | **yes: one tap goes home** |
| Cold deep link `/characters` | [05_deep_link_characters.png](verifier/e2e/05_deep_link_characters.png) | "Characters" with an empty leading slot: the flow is the router root, nothing below | yes (accepted empty slot, F-0035) |
| Link after the flow | [06_link_after_flow.png](verifier/e2e/06_link_after_flow.png) | "Placeholder 42" with a chevron, "Placeholder detail 42" | yes |

`01_home`–`04_full_profile_placeholder` from the committed journey are also in [e2e/](verifier/e2e/).

## Issues found
None blocks an AC.

1. **(minor, test gap) The `isFirst` choice is not pinned.**
   - Location: `feature_flow.dart:279` `outerCanPop: route != null && !route.isFirst`.
   - What survives: V9 (`route?.canPop ?? false`) and V10 (`Navigator.of(context).canPop()`, with the route dependency kept) pass every committed test.
   - What would kill them: my VP8 (a local history entry on the outer route of an app-root flow) kills both, and VP9 (a dialog above an app-root flow) kills V10 ([log](verifier/probe_under_signal_mutants.log)).
   - Suggest adding VP8 as a T-0037-AC1 test.
2. **(minor, edge-case staleness) The button can stay visible with nothing below the flow.** If the flow's own outer route holds a local history entry and the routes below then change, `outerCanPop` is not recomputed.
   - Location: `feature_flow.dart:260`.
   - Cause: `_ModalScopeStatus` only notifies when `isCurrent`, `canPop`, `impliesAppBarDismissal`, `route` or `opaque` change, and with the entry present `canPop` and `impliesAppBarDismissal` stay true.
   - Repro, VP10: push the flow, `ModalRoute.of(flowCtx).addLocalHistoryEntry(LocalHistoryEntry())`, then `removeRoute(home)`. The result is `outerCanPop=true`, 1 back button, `isFirst=true`.
   - Effect: the first tap removes the hidden entry, and only then does the button disappear.
   - Scope: it needs local history on the outer route (an outer `Scaffold` around the flow with a persistent sheet or an open drawer). The app and the bricks don't do that today. Suggest a pending-work item.
3. **(nit, design note for the bricks) A nested non-flow `Navigator` inside a flow page.** The first route of that navigator finds the enclosing `FlowScope` and acts as a flow root.
   - Location: `flow_context.dart:129`.
   - Repro, VP18: a flow with 2 pages, where page 2 is a `Navigator`. Its first route shows a `BackButton` (AppBar would show nothing). The tap does nothing, because flow_builder's `PopScope(canPop: false)` blocks the outer `maybePop`.
   - It is unchanged from T-0036 (`FlowScope.read` there). It matters only if a brick generates nested navigators (tabs).
4. **(nit, test gap, pre-existing) The off-flow branch's `impliesAppBarDismissal` check is unpinned.** V19 (`impliesAppBarDismissal && canPop` → `canPop`, `flow_context.dart:146`) survives. No test uses a `LocalHistoryEntry(impliesAppBarDismissal: false)` outside a flow.
5. **(nit, docs and scripts)**
   - `VENDORED.md:9`: the Task row lists findings F-0034 and F-0035 but not F-0036.
   - `tool/checks/T-0036-AC3_gates.sh:22` still exports `MC_TASK=T-0036`. The T-0033 mutation script therefore logs to `/tmp/mc-T-0036-<role>-mutations.log`, which is the T-0036 naming, not T-0037's. The output base is now passed through `MC_OB`, so there is no server collision.

## Notes for the Tech Lead
- I saw no reason to retry anything: no flaky run, and every gate passed first time.
- Issues 1 and 2 are cheap follow-ups: one more test, and an ADR-less pending-work note or a `RouteAware`-style recompute. They can ride with the P1-24 bricks task or a small T-0038.
- The new `FeatureFlow` dependency on `ModalRoute` re-runs the `FutureBuilder` builder whenever `isCurrent` flips (a push or pop over the flow). `FlowScope` only notifies when `container` or `outerCanPop` changes, and `FlowBuilder`'s `didUpdateWidget` takes neither branch, so no page rebuilds. VP1 confirms the root page build count stays the same.
