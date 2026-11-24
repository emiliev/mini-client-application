# Verification report — T-0022: `mc_bloc_kit` + `mc_feature_flow` (with the flow_builder spike)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0022-feature-flow` @ **`4ca3702`** (rebased onto main `c9dc283`; per-depth snapshots, and `restore` now notifies `states`), checked out as `fleet/T-0022-verify3`. This supersedes the rounds at `496e8bb` and `cd30e2e` (both FAIL on AC5), summarised at the end.
- **Simulator:** none. This is a utility task with no e2e journey, and Android is deferred (Q-009).
- **Bazel output base:** `/tmp/mc-ob-T-0022-verifier` (the Verifier's own).
- **Verdict:** **PASS**. Every AC passes.

## Gates re-run independently (at `4ca3702`)
| Gate | Command | Result |
|---|---|---|
| L1–L3 Tests | `tool/bazelw test --nocache_test_results //...` | **36 / 36 pass** |
| L0 Lint (format + analyze aspects) | `tool/bazelw build --config=lint //...` | pass |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| L4 E2E | n/a (utility task) | — |

Logs: [`verifier/gates.log`](verifier/gates.log). My probes: [`verifier/probes-cd30e2e.dart.txt`](verifier/probes-cd30e2e.dart.txt), unchanged since the last round. I appended them to `feature_flow_test.dart` temporarily and never committed them.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0022-AC1 | no initializer → first page renders | `feature_flow_test` "T-0022-AC1 …" | Yes. It pumps a flow without a `flowInitializer` and finds `list page`. This is Tide's "never builds" defect, fixed. | PASS |
| T-0022-AC2 | throwing initializer → error view, Retry, `recordError`; Retry re-runs | "T-0022-AC2 …" | Yes. It checks for `Retry` and the fixed message, that the raw error is not shown, and that there is exactly 1 `ErrorEntry`. After the Retry tap it asserts `attempts == 2` and that the first page renders. | PASS |
| T-0022-AC3 | `complete(r)` → `onComplete(r)` exactly once | widget "T-0022-AC3 …"; `feature_flow_controller_test` | Yes. `complete('done')` then `complete('again')` gives exactly `['done']`. A late `update`, `restore` or `complete` after `dispose` is a no-op: no throw, no state change, no emission, and `isCompleted` stays false. | PASS |
| T-0022-AC4 | two flows in an `IndexedStack` → own controllers | "T-0022-AC4 …" | Yes. Each flow resolves its controller through `context.di` from its own `FlowScope`. The controllers are distinct, with states `a` and `b`. | PASS |
| T-0022-AC5 | iOS edge swipe → state reverts; the page has its declared `name` | "T-0022-AC5 …" ×4 in `feature_flow_test`; "T-0022-AC5 update and restore both notify states" in `feature_flow_controller_test` | Yes. Each test uses a real drag from x=2 on iOS, asserts the route name `detail`, and asserts both the state **and** the visible text after each swipe. **My probes** (state and visible content) all pass; see the next table. **Mutant 1** (broadcast removed from `restore`): content assertions in "a filter changed on the list …" (`list foo` not found) and "two pushes then two edge swipes …" (`detail b` not found) **fail**, as do the unit test (`[1, 0]` vs `[1]`) and my VPROBE2 and VPROBE3. **Mutant 2** (round 2, per-depth fix removed): two of the new tests fail. | PASS |
| T-0022-AC6 | missing `RootImport<T>` names `T`; `debugResolveAll` names both types | widget "T-0022-AC6 …" ×2; `mc_di/test/recording_test.dart` (10) | Yes. The `StateError` names `_Dep`. `debugResolveAll` names `_Other` and `_Missing` (widget) and `_B` and `_A` (unit). Scoped registrations (`pushNewScope`, `popScope`, `dropScope`, `unregister`, `reset`) are tracked. `signalsReady` and `dependsOn` fail with "not ready" plus the type within the timeout. No change since round 1. | PASS |
| T-0022-AC7 | `mc_bloc_kit` has no Flutter and no mixins; gates; spike finding | `purity_test`, `mc_bloc_test` (3), gates, F-0018 | Yes. The purity test scans `lib/**`, and a hand grep finds only the word "mixin" in a doc comment. The deps are `bloc` and `mc_monitoring` only. `McBloc` is an `abstract base class` that logs transitions and records failures. The gates are green and F-0018 is present. | PASS |

### My AC5 probes at `4ca3702` (state and visible content after each swipe)
| Probe | Steps | State after the swipe | Visible | Result |
|---|---|---|---|---|
| VPROBE1, filter case | list filter `foo` → push detail `x` → swipe | `(foo, null)` | `vlist foo`, no `vdetail` | PASS |
| VPROBE2, reviewer's case | filter `foo` → push detail `x` → in place inside detail: detail `y`, filter `bar` → swipe | `(foo, null)` (pre-push) | `vlist foo`, no `vdetail` | PASS |
| VPROBE3, two levels | filter `foo` → push detail `a` → in place `b` → push sub `s` → in place sub `t`, detail `z` → swipe → swipe → filter `qux`, push `c`, swipe | `(foo, b, null)`, then `(foo, null)`, then `(qux, null)` | `vdetail b` (no `vsub`), then `vlist foo`, then `vlist qux` | PASS |
| VPROBE4, same-depth replace (extra) | push detail → replace it with `settings` → swipe | `(none, null)` | `vlist none` (pages match state) | PASS |

## Other checks
- **F-0018** now matches the code. §5 says the switches are forwarded under the ignore. §8 says `restore` notifies `states` so the pages show the restored content, records the Verifier finding and the mutation results, and states a limit: a single pop that removes several pages is not handled.
- **The `restore` contract changed.** It used to say "does not notify, so the host does not hear its own change". Now it notifies, and `FeatureFlow`'s own listener (`_onControllerState`) does receive it. I checked the code: after a pop the page names of the restored snapshot equal flow_builder's, so nothing is forwarded back. In the replace case (VPROBE4) the forward runs under `_forwarding`, so there is no feedback loop. All probes confirm this.
- **Spike claim:** confirmed. `flutter.toolchain(flutter_version = "3.47.7")`, Dart 3.13.5, `flow_builder 0.1.0` in `pubspec.lock`, and `feature_flow_test` passes under Bazel `flutter_test`, including the real edge-swipe pop through flow_builder's `onPopPage`.
- **Tide conformance:** it matches the article (flow_builder `FlowBuilder` over `MaterialPage`s; `FeatureFlowController<T>` is registered in the flow's scope before the feature initializer; blocs navigate through `controller.update`; back reverts the state; the flow is the feature's entry widget). The deviations are justified:
  - **R17/D-17:** a child `GetIt` per flow, with `RootImport` and `context.di` instead of the global `pushNewScope`, `dropScope` and `diContainer<T>()`. This fixes Tide's tab shadowing, as AC4 proves.
  - **D-16:** `McBloc` is an `abstract base class` rather than a per-bloc override or a mixin. It gives one logging point and keeps the outline cutoff.
  - **D-18:** the hardening (builds without an initializer, Retry, named pages, `complete`/`onComplete`).
  - **R15:** `FeatureFlowController` is pure Dart, bridged to flow_builder by `FeatureFlow`. It owns its state, and the per-depth snapshots fix flow_builder's history, which can't distinguish in-place updates.

## Test-integrity audit and hygiene
- **Tests deleted, skipped or weakened:** none. In `4ca3702` one unit test was **renamed and its expectation changed**: "T-0022-AC3 update notifies states; restore does not" (`[1]`) became "T-0022-AC5 update and restore both notify states" (`[1, 0]`). This follows the intended contract change in `restore` and is declared in the commit message. Two AC5 widget tests gained in-place updates and absent-text assertions, which makes them stronger.
- **Lint suppressions:** only the TL-approved `// ignore_for_file: invalid_use_of_visible_for_testing_member` in `mc_di/lib/src/recording_get_it.dart`. In round 1, removing it produced exactly 4 warnings, all on the two forwarded get_it switches. The file is unchanged since.
- **`mc_di`:** the existing `di_container_test` is unchanged and passes.
- **Root changes:** `pubspec.yaml` (+2 workspace members), `pubspec.lock` (+`bloc`, +`flow_builder`) and `MODULE.bazel.lock`, as listed.
- **Worktree:** every mutant and probe was reverted with `git checkout`. The tree was clean before lint, arch_check and this commit.

## Non-blocking notes for the Tech Lead
1. **Multi-page pops** (for example `Navigator.popUntil` inside a flow's navigator) are not handled, as F-0018 §8 states. Edge-swipe and AppBar back pop one page at a time, which is what AC5 covers. Consider a `pending-work.md` entry.
2. **Plan §4.5 items outside this task's scope:** `FeatureFlow<S, R>`, `provide`, `localizationsDelegates` and `name` are not implemented. They belong in `pending-work.md` if not already tracked.

## Earlier rounds (superseded)
- **`496e8bb`: FAIL on AC5.** Only page-changing updates were forwarded to flow_builder, so a list-page in-place update made before a push was lost on back (state `'none'` instead of `'foo'`). The mutant with the history fix removed failed the then-new AC5 test as expected. Minor issues then (F-0018 §5 contradicting the code, a stale test comment, a 6-test Engineer log) were all fixed in `cd30e2e`.
- **`cd30e2e`: FAIL on AC5.** The per-depth snapshots made the state correct in every case. But `restore` did not notify `states`, so after a pop the `_LivePage` content showed the last emitted state: VPROBE2 showed `vlist bar` where the state was `foo`, and VPROBE3 showed `vdetail z` where it was `b`. Fixed in `4ca3702`.
