# T-0022: `mc_bloc_kit` + `mc_feature_flow` (P1-04, with the flow_builder spike)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0022-feature-flow` |
| Created | 2026-11-23 |
| Depends on | T-0017 (`mc_di`), T-0020 (`mc_monitoring`), T-0019 (DS error and loading views) |
| Related | [plan 01 §3, §4, P1-04, D-16, D-17](../plan/01-architecture-and-modules.md), [Tide navigation research](../research/tide-miniclient/app-navigation-testing.md) §3, R15, R16, R17 |

## Goal
Tide's `feature_flow` utility (intra-feature navigation over `flow_builder`) plus the bloc base kit that every feature uses.

## Scope
- **In:**
  - `utility/mc_bloc_kit` (**pure Dart**, no mixins): `abstract base class McBloc` (central transition and error logging to `mc_monitoring`, D-16), and `FeatureFlowController<T>`.
  - `utility/mc_feature_flow` (Flutter): `FeatureFlow<T>` over `flow_builder`, with a per-flow child DI container using `RootImport` (R17), `context.di<T>()`, `flowInitializer` with error and Retry (DS `McErrorView`), `complete(result)` → `onComplete`, page names, iOS back-gesture support, and `debugResolveAll()`.
  - **The flow_builder spike:** confirm flow_builder works on Flutter 3.47.7 under Bazel; if not, implement the Navigator 2.0 Pages fallback behind the same API (plan 01 C11).
- **Out:** features.

## Acceptance criteria
- **T-0022-AC1:** Given no `flowInitializer`, when pumped, then the first page renders.
- **T-0022-AC2:** Given a throwing initializer, then an error view with Retry shows and `recordError` is called; Retry re-runs it.
- **T-0022-AC3:** Given `complete(r)`, then `onComplete` receives `r` exactly once.
- **T-0022-AC4:** Given two instances of one flow in an `IndexedStack`, then each resolves its own controller.
- **T-0022-AC5:** Given a pushed page, when back is triggered by the iOS edge-swipe gesture (not only `Navigator.pop`), then the flow state reverts and the page has its declared `name`.
- **T-0022-AC6:** Given a `RootImport<T>` with no root registration, when the flow is created, then it fails naming `T`. Given `debugResolveAll()` and a registration with a missing dependency, then it fails naming both types.
- **T-0022-AC7:** `mc_bloc_kit` imports no Flutter and declares no mixins. `test //...`, lint and `mc_arch_check` pass, and the flow_builder spike result is recorded as a finding.

## Log
- 2026-11-23: Created.
- 2026-11-23: Engineer implemented `mc_bloc_kit`, `mc_feature_flow` and `ChildDIContainer.debugResolveAll` in `mc_di`. Spike: flow_builder 0.1.0 works ([F-0018](../findings/F-0018-flow-builder-spike.md)). Handed off for verification.
- 2026-11-24: Fixed the 5 review issues and nits: pages and flow history kept in step (forward only structural updates, live page content), `FeatureFlowController` no-ops after dispose, `RecordingGetIt` tracks unregister, reset and scopes, `debugResolveAll` awaits `signalsReady`, async and `dependsOn` registrations with a named timeout, scope `init` goes through the recorder. Evidence now committed (the `bazel-*` ignore rule hid the old name; renamed `test-output.log`). Finding renumbered F-0017 to F-0018.
- 2026-11-24: Verifier FAIL on AC5 fixed: per-depth state snapshots (pop to depth n restores the depth-n snapshot). Three edge-swipe tests (in-place selection, filter then push then back, two levels). Mutation checks: restore-flow_builder-state fails the filter and two-level tests; forward-everything fails the in-place and two-level tests. Rebased on origin/main; full run 36/36 (evidence log).
- 2026-11-24: Verifier FAIL (stale page content after swipe): `restore` now notifies `states`; edge-swipe tests assert visible text. Mutation (no broadcast) fails the filter and two-level tests.

## Outcome
**Engineer handoff.** Gates: `tool/bazelw test --nocache_test_results //...` 32/32 pass, `build --config=lint //...` pass, `run //tool/mc_arch_check:bin` OK. Evidence: `documents/evidence/T-0022/engineer/test-output.log`.

| AC | Test |
|---|---|
| AC1 | `mc_feature_flow/test/feature_flow_test.dart` "T-0022-AC1 ..." |
| AC2 | same file, "T-0022-AC2 ..." (error view, `recordError`, Retry re-runs) |
| AC3 | same file "T-0022-AC3 complete(r) ..."; `mc_bloc_kit/test/feature_flow_controller_test.dart` |
| AC4 | same file, "T-0022-AC4 ..." |
| AC5 | same file, "T-0022-AC5 iOS edge swipe ..." (real drag gesture, route name `detail`) |
| AC6 | same file (unregistered root import; `debugResolveAll` names both types); `mc_di/test/recording_test.dart` |
| AC7 | `mc_bloc_kit/test/purity_test.dart` (no Flutter import, no `mixin`); `mc_bloc_test.dart` (McBloc logging); gates above; finding F-0018 |

Deviations and notes:
- `mc_di` was changed (`RecordingGetIt`, `ChildDIContainer.debugResolveAll`, a new test target) because AC6 needs registration recording (plan 01 U03). No existing test was changed.
- `FeatureFlow` takes `List<McFlowPage>` (name + child) instead of bare widgets, so pages carry names. `FeatureFlowController<T>.complete([Object? result])` is untyped on the result; the plan's `<S,R>` form was not used because the task text says `<T>`.
- One `// ignore_for_file: invalid_use_of_visible_for_testing_member` in `mc_di/lib/src/recording_get_it.dart`, to forward get_it's two `@visibleForTesting` switches. No tests skipped or weakened; one test assertion changed (AC2 now expects the fixed Retry message, with the raw error going to monitoring only).
- Review fixes are tested by `T-0022-AC5` (in-place update then swipe), `T-0022-AC3` (late complete after dispose) and `T-0022-AC6` (unregister, reset, pushNewScope, popScope, dropScope, signalsReady, never-ready dependency, async singleton).
- Root changes: `pubspec.yaml` (two workspace members), `pubspec.lock` (`bloc 9.2.1`, `flow_builder 0.1.0`), `MODULE.bazel.lock`.

