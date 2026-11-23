# Verification report — T-0022: `mc_bloc_kit` + `mc_feature_flow` (with the flow_builder spike)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0022-feature-flow` @ `496e8bb` (the original `2f13f65` plus review fixes), checked out as `fleet/T-0022-verify`
- **Simulator:** none. This is a utility task with no e2e journey, and Android is deferred (Q-009).
- **Bazel:** the Verifier's own output base (`mc-ob-T-0022-verifier`). All gates were re-run on it after the coordinator warned that an output base had been shared with the T-0023 Verifier.
- **Verdict:** **FAIL**. AC5 fails on a realistic case (Issue 1). AC1 to AC4, AC6 and AC7 pass.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| L1–L3 Tests | `tool/bazelw test --nocache_test_results //...` | **32 / 32 pass** |
| L0 Lint (format + analyze aspects) | `tool/bazelw build --config=lint //...` | pass |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| L4 E2E | n/a (utility task) | — |

Logs: [`verifier/gates.log`](verifier/gates.log).

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0022-AC1 | no initializer → first page renders | `feature_flow_test` "T-0022-AC1 …" | Yes. It pumps a flow without a `flowInitializer` and finds `list page`. This is Tide's "never builds" defect, fixed. | PASS |
| T-0022-AC2 | throwing initializer → error view, Retry, `recordError`; Retry re-runs | "T-0022-AC2 …" | Yes. It checks for `Retry` and the fixed message, that the raw error is not shown, and that there is exactly 1 `ErrorEntry` in the monitoring sink. After the Retry tap it asserts `attempts == 2` and that the first page renders. | PASS |
| T-0022-AC3 | `complete(r)` → `onComplete(r)` exactly once | widget "T-0022-AC3 complete(r) …"; `feature_flow_controller_test` (4 tests) | Yes. The widget test calls `complete('done')` and then `complete('again')`, and `onComplete` receives exactly `['done']`. **Late complete after dispose:** the unit test disposes the controller, then calls `update`, `restore` and `complete`. All return normally, the state is unchanged, `isCompleted` is false and nothing is emitted. `dispose` sets `_disposed` synchronously before closing the streams, and `_FeatureFlowState.dispose` disposes the controller. No widget-level "complete after unmount" test exists, but the unit test covers the no-op. | PASS |
| T-0022-AC4 | two flows in an `IndexedStack` → own controllers | "T-0022-AC4 …" | Yes. Each flow resolves its controller through `context.di` from its own `FlowScope`. The two controllers are not identical, and their states are `a` and `b`. | PASS |
| T-0022-AC5 | iOS edge swipe → state reverts; the page has its declared `name` | "T-0022-AC5 iOS edge swipe …", "T-0022-AC5 an in-place update then an edge swipe …" | The tests are genuine: a real drag from x=2 with `platform: iOS`, the route name `detail` is asserted, and `controller.state.selected` is asserted null. **Mutation:** with the history-vs-pages fix removed (every update forwarded to flow_builder), the new test **fails** (`Expected: null, Actual: 'x'`) and the others still pass, so the test guards the fix. **But the fix breaks a different case (Issue 1):** after an in-place update on the root page, a push and a swipe back, the state reverts to a stale value. | **FAIL** |
| T-0022-AC6 | missing `RootImport<T>` names `T`; `debugResolveAll` names both types | widget "T-0022-AC6 …" ×2; `mc_di/test/recording_test.dart` (10 tests) | Yes. The widget test sees a `StateError` that contains `_Dep`, rethrown from `build` rather than shown as a Retry view. The `debugResolveAll` tests (widget and unit) check that the message contains both `_Other` and `_Missing`, and both `_B` and `_A`. **Scoped registrations:** `pushNewScope` registrations are recorded and fail naming both types. `popScope`, `dropScope('one')` (only that scope), `unregister` and `reset` all forget their entries. **Readiness:** a `signalsReady` singleton that never signals, and a `dependsOn` on a never-completing async singleton, both fail with "not ready" plus the type within the 50 ms timeout instead of hanging. A real async singleton is awaited. | PASS |
| T-0022-AC7 | `mc_bloc_kit` has no Flutter and no mixins; gates; spike finding | `purity_test`, `mc_bloc_test` (3), gates, F-0018 | Yes. The purity test scans `lib/**` for `package:flutter` or `dart:ui` imports and exports, and for `mixin` declarations. I grepped by hand too: the only hit is the word "mixin" in a doc comment. `pubspec.yaml` depends only on `bloc` and `mc_monitoring`. `McBloc` is an `abstract base class`, and the tests check that it logs transitions, records `McFailureState` transitions and records `addError`. All gates are green and F-0018 exists. | PASS |

## Issue 1 (important, fails AC5): an in-place update on a lower page is lost on back
`_onControllerState` forwards to flow_builder only those updates that change the page-name list. flow_builder records a history entry only on `update`, and on pop it restores `_history.last` (`flow_builder.dart:187-191`). So any in-place update made **before** a push is missing from flow_builder's history, and the pop "reverts" past it.

Repro (a temporary test, not committed; `FeatureFlow<(String, String?)>`, where `$1` is a filter on the `list` page and `$2` a selection that pushes `detail`):
1. `update((s) => ('foo', s.$2))`: an in-place update, not forwarded. The list shows `filter foo`.
2. `update((s) => (s.$1, 'x'))`: a push, forwarded. flow_builder's history is `[('none', null), ('foo', 'x')]`.
3. Edge swipe back. flow_builder restores `('none', null)`, `controller.state.$1` is **`'none'`** (expected `'foo'`), and the list shows `filter none`.

On `496e8bb` the probe **fails** (`Expected: 'foo', Actual: 'none'`). On the mutated pre-fix code it **passes**, and the new AC5 test fails instead. The review fix traded one state-vs-history divergence for another. This is the Marvel-style case of a filter or search on the list, then opening a detail page. F-0018 §8 ("keeps state and pages in step") overstates the fix.

Suggested direction (the Engineer's call): keep `FeatureFlow`'s own history, one entry per page stack. An in-place update replaces the top entry, and a structural update pushes an entry. On a flow_builder pop, restore from that history instead of from flow_builder's value. Or move to the C11 Navigator `pages` and `onDidRemovePage` fallback. Add the probe above as an AC5 test.

## Other issues (minor)
2. **F-0018 §5 contradicts the code and §10.** It says the two `@visibleForTesting` switches are "stored as plain fields instead of forwarding (forwarding fails the lint)". The code forwards them under the file-level ignore, as §10 says.
3. **Stale test comment.** In "T-0022-AC6 debugResolveAll names both types", the comment says the missing dependency is `_Selection`. It is `_Missing`.
4. **Engineer evidence is partial.** `engineer/test-output.log` shows `Executed 6 out of 6 tests` (the T-0022 and `mc_di` targets). The Outcome claims 32/32 for `//...`. My independent run confirms 32/32, so this affects only the evidence.
5. **Plan §4.5 scope gap (for the TL, not an AC):** `FeatureFlow<S, R>`, `provide`, `localizationsDelegates` and `name` are not implemented. The task scope says `<T>` and doesn't list them, so this is pending work, not a defect here.

## Tide conformance
- **Matches the article:** `FeatureFlow<T>` is a `StatefulWidget` with `state`, `onGeneratePages` and `flowInitializer`. It builds `ColoredBox(scaffoldBackground)` → `FutureBuilder` → `FlowBuilder<T>` over `MaterialPage`s. It registers `FeatureFlowController<T>` as a singleton in the flow's scope **before** the feature initializer runs. Blocs drive navigation through `controller.update(...)`, and a gesture pop reverts the state. The flow is the feature's entry widget.
- **Deviations, all justified:**
  - **R17/D-17:** a child `GetIt.asNewInstance()` per flow, published through an `InheritedWidget` (`FlowScope`), with `RootImport<T>` and `context.di<T>()`. This replaces the global `pushNewScope(hashCode)`, `dropScope` and `diContainer<T>()`, and fixes the Tide defect where tabs shadow each other (AC4 proves it).
  - **D-16:** `McBloc` is an `abstract base class` rather than a per-bloc `onTransition` override or a mixin. It gives one logging point and keeps the outline cutoff.
  - **D-18 hardening:** it builds without an initializer, an initializer error shows an error view with Retry and `recordError`, pages are named and keyed (`McFlowPage`), and it adds `complete` and `onComplete`.
  - **`FeatureFlowController` lives in pure-Dart `mc_bloc_kit` (R15),** so it owns its state and streams instead of wrapping flow_builder's `FlowController`. `FeatureFlow` bridges the two. That bridge is where Issue 1 sits.
  - **`onGeneratePages` returns `List<McFlowPage>`,** not `List<Widget>`, so pages carry names.

## Spike claim (F-0018)
Confirmed. `MODULE.bazel` pins `flutter.toolchain(flutter_version = "3.47.7")`, and the Bazel SDK is Dart `3.13.5`. `pubspec.lock` resolves `flow_builder 0.1.0` (and `bloc 9.2.1`). `//utility/mc_feature_flow:feature_flow_test` compiles and passes under `flutter_test`, including a real iOS edge-swipe pop through flow_builder's deprecated `onPopPage`. No lint warning comes from it.

## Test-integrity audit and hygiene
- **Tests deleted, skipped or weakened:** none. The existing `mc_di/test/di_container_test.dart` is unchanged and passes. One assertion changed: AC2 now expects the fixed message, which the handoff declared.
- **Lint suppressions:** one, `// ignore_for_file: invalid_use_of_visible_for_testing_member` in `mc_di/lib/src/recording_get_it.dart` (approved by the TL). I removed it temporarily and ran lint on `//utility/mc_di/...`. Exactly 4 warnings appeared, all on the forwarding getters and setters of `skipDoubleRegistration` and `allowRegisterMultipleImplementationsOfoneType` (lines 267 to 277). So the suppression covers only that purpose. I then restored it.
- **`mc_di` changes:** `createChildContainer` now runs initializers through `RecordingGetIt`. Root `initializeDIContainer` is untouched. `di_container_test` passes.
- **Root changes, as listed:** `pubspec.yaml` (+`utility/mc_bloc_kit`, +`utility/mc_feature_flow`), `pubspec.lock` (+`bloc`, +`flow_builder` only) and `MODULE.bazel.lock`. Nothing else outside the two new packages, `utility/mc_di` and `documents/` changed.
- **Golden files:** none.
- **Worktree:** every mutation and probe was reverted with `git checkout`, and `git status` was clean before this report was committed.

## Notes for the Tech Lead
- Send T-0022 back to the Engineer for Issue 1, with a test for the root-page in-place-update-then-push-then-swipe case. Issues 2 and 3 are one-line fixes in the same pass.
- Consider adding plan §4.5's `<S, R>`, `provide`, `localizationsDelegates` and `name` to `pending-work.md` if they are not already tracked.
