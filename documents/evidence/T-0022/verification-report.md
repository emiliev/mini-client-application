# Verification report — T-0022: `mc_bloc_kit` + `mc_feature_flow` (with the flow_builder spike)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0022-feature-flow` @ **`cd30e2e`** (rebased onto main `c9dc283`; per-depth snapshot design for AC5), checked out as `fleet/T-0022-verify2`. This supersedes the first verification of `496e8bb` (FAIL on AC5), summarised at the end.
- **Simulator:** none. This is a utility task with no e2e journey, and Android is deferred (Q-009).
- **Bazel output base:** `/tmp/mc-ob-T-0022-verifier` (the Verifier's own).
- **Verdict:** **FAIL**. The flow *state* is now right in every back case. But after a swipe back the *page content* can show a state that no longer exists (Issue 1), so AC5 still fails. AC1 to AC4, AC6 and AC7 pass.

## Gates re-run independently (at `cd30e2e`)
| Gate | Command | Result |
|---|---|---|
| L1–L3 Tests | `tool/bazelw test --nocache_test_results //...` | **36 / 36 pass** |
| L0 Lint (format + analyze aspects) | `tool/bazelw build --config=lint //...` | pass |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| L4 E2E | n/a (utility task) | — |

Logs: [`verifier/gates.log`](verifier/gates.log). My probes: [`verifier/probes-cd30e2e.dart.txt`](verifier/probes-cd30e2e.dart.txt). I appended them to `feature_flow_test.dart` temporarily, with a dump of the visible `Text` widgets after each swipe; they were never committed.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0022-AC1 | no initializer → first page renders | `feature_flow_test` "T-0022-AC1 …" | Yes. It pumps a flow without a `flowInitializer` and finds `list page`. This is Tide's "never builds" defect, fixed. | PASS |
| T-0022-AC2 | throwing initializer → error view, Retry, `recordError`; Retry re-runs | "T-0022-AC2 …" | Yes. It checks for `Retry` and the fixed message, that the raw error is not shown, and that there is exactly 1 `ErrorEntry`. After the Retry tap it asserts `attempts == 2` and that the first page renders. | PASS |
| T-0022-AC3 | `complete(r)` → `onComplete(r)` exactly once | widget "T-0022-AC3 …"; `feature_flow_controller_test` (4) | Yes. `complete('done')` then `complete('again')` gives exactly `['done']`. A late `update`, `restore` or `complete` after `dispose` is a no-op: no throw, no state change, no emission, and `isCompleted` stays false. | PASS |
| T-0022-AC4 | two flows in an `IndexedStack` → own controllers | "T-0022-AC4 …" | Yes. Each flow resolves its controller through `context.di` from its own `FlowScope`. The controllers are distinct, with states `a` and `b`. | PASS |
| T-0022-AC5 | iOS edge swipe → state reverts; the page has its declared `name` | "T-0022-AC5 …" ×4 (basic; in-place then swipe; filter then push then swipe; two levels) | The tests are genuine: a real drag from x=2 on iOS, the route name `detail` is asserted, and the state is asserted. **Full mutant** (per-depth fix removed, pre-`496e8bb` forwarding restored): "in-place update then edge swipe" and "two pushes then two edge swipes" **fail**, so the new tests guard the fix. **My own repros:** the state is correct in all of them, but in 2 of 4 the page shows stale content (Issue 1). | **FAIL** |
| T-0022-AC6 | missing `RootImport<T>` names `T`; `debugResolveAll` names both types | widget "T-0022-AC6 …" ×2; `mc_di/test/recording_test.dart` (10) | Yes. Nothing changed since the first verification, and everything still passes. The stale `_Selection` comment is fixed. | PASS |
| T-0022-AC7 | `mc_bloc_kit` has no Flutter and no mixins; gates; spike finding | `purity_test`, `mc_bloc_test` (3), gates, F-0018 | Yes. Unchanged, and the gates are green. | PASS |

### My AC5 repros at `cd30e2e` (state vs what is on screen after each swipe)
| Probe | Steps | `controller.state` after the swipe | Visible | Result |
|---|---|---|---|---|
| VPROBE1, my regression case | list filter `foo` → push detail `x` → swipe | `(foo, null)` ✓ | `vlist foo` ✓ | PASS |
| VPROBE2, the reviewer's case | filter `foo` → push detail `x` → in place inside detail: detail `y`, filter `bar` → swipe | `(foo, null)` ✓ (pre-push) | **`vlist bar`** ✗ | **FAIL** |
| VPROBE3, two levels | filter `foo` → push detail `a` → in place `b` → push sub `s` → in place sub `t`, detail `z` → swipe → swipe → filter `qux`, push `c`, swipe | 1st: `(foo, b, null)` ✓; 2nd: `(foo, null)` ✓; re-push and swipe: `(qux, null)` ✓ | 1st swipe: **`vdetail z`** ✗ (state says `b`) | **FAIL** |
| VPROBE4, same-depth replace (extra) | push detail → replace it with `settings` (same depth) → swipe | `(none, null)` | `vlist none` | PASS (pages match state) |

## Issue 1 (important, fails AC5): page content is not updated when a pop restores a snapshot
`_onFlowChanged` restores the depth snapshot with `FeatureFlowController.restore(...)`, which by design does **not** emit on `states`. `_LivePage` builds page content from a `StreamBuilder` on `controller.states`, so after a pop it keeps the **last emitted** state. Any in-place change made on the popped page that also touches data shown by the revealed page (VPROBE2: the filter), or by a page below (VPROBE3: the detail), stays on screen while the controller holds the restored snapshot. The screen and the bloc-visible state then disagree, which is the class of bug AC5 exists to prevent.

The Engineer's tests miss it by coincidence. In "filter then push" the last emission before the pop already carries `filter: foo`. In "two levels" the only in-place change at depth 2 happens before the push to depth 3.

Diagnosis confirmed by an experiment, which is not a proposed fix. Replacing `restore(restored)` with `update((_) => restored)` makes all 4 probes and all 10 tests pass. That shortcut is wrong as shipped (`update` is ignored after `complete`, and it re-enters `_onControllerState`), but it shows that notifying the live pages is the missing piece. Suggested direction: drive `_LivePage` from a `ValueNotifier<T>` (or `setState`) owned by `_FeatureFlowState`, set in both `_onControllerState` and `_onFlowChanged`. Then add VPROBE2 and VPROBE3, with their visible-text assertions, as AC5 tests.

## Other checks
- **F-0018 now matches the code for §5** (the switches are forwarded under the file-level ignore). **§8 is still slightly overstated:** "keeps `FeatureFlowController.state` authoritative … Page content follows in-place updates through a `StreamBuilder`" is true, but restored state never reaches the `StreamBuilder` (Issue 1). Update it with the fix.
- **Engineer evidence** now shows `Executed 36 out of 36 tests`, so the partial-log issue from the first round is closed.
- **Spike claim:** confirmed. `flutter.toolchain(flutter_version = "3.47.7")`, Dart 3.13.5, `flow_builder 0.1.0` in `pubspec.lock`, and `feature_flow_test` passes under Bazel `flutter_test`, including the real edge-swipe pop through flow_builder's `onPopPage`.
- **Tide conformance:** unchanged from the first round. It matches the article (flow_builder `FlowBuilder` over `MaterialPage`s; the controller is registered in the flow's scope before the feature initializer; blocs navigate through `controller.update`; the flow is the feature's entry widget). The deviations are justified: R17/D-17 child `GetIt` per flow with `RootImport` and `context.di` (fixes tab shadowing, proven by AC4); D-16 `McBloc` as an `abstract base class` (one logging point, keeps the outline cutoff); D-18 hardening; `FeatureFlowController` in pure-Dart `mc_bloc_kit` (R15), bridged to flow_builder by `FeatureFlow`, which is where Issue 1 sits.
- **Plan §4.5 scope gap (for the TL, not an AC):** `FeatureFlow<S, R>`, `provide`, `localizationsDelegates` and `name` are not implemented. They are outside this task's scope, so they belong in `pending-work.md` if not already tracked.

## Test-integrity audit and hygiene
- **Tests deleted, skipped or weakened:** none. Three AC5 tests were added and one comment was fixed. The `mc_di` tests are unchanged and pass.
- **Lint suppressions:** only the TL-approved `// ignore_for_file: invalid_use_of_visible_for_testing_member` in `mc_di/lib/src/recording_get_it.dart`. In the first round, removing it produced exactly 4 warnings, all on the two forwarded get_it switches. The file is unchanged since, so the suppression is still limited to that purpose.
- **Root changes:** `pubspec.yaml` (+2 workspace members), `pubspec.lock` (+`bloc`, +`flow_builder`) and `MODULE.bazel.lock`, as listed.
- **Worktree:** every mutant, probe and experiment was reverted with `git checkout`. The tree was clean before lint, arch_check and this commit.

## First verification at `496e8bb` (superseded)
FAIL on AC5. Only page-changing updates were forwarded to flow_builder, so a list-page in-place update made before a push was lost on back (state `'none'` instead of `'foo'`). The mutant with the history fix removed failed the then-new AC5 test as expected. Minor issues then: F-0018 §5 contradicted the code, a stale test comment, and the Engineer log showed 6 tests rather than 32. All three are fixed in `cd30e2e`.

## Notes for the Tech Lead
- Send T-0022 back for Issue 1. It is a small change: notify the live pages on restore. Add VPROBE2 and VPROBE3 (with visible-text assertions) as AC5 tests and update F-0018 §8.
- Everything else is ready. AC1 to AC4, AC6, AC7, the gates, the spike, hygiene and Tide conformance all pass.
