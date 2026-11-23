# T-0022: `mc_bloc_kit` + `mc_feature_flow` (P1-04, with the flow_builder spike)

| Field | Value |
|---|---|
| Status | Ready (dispatch after T-0020 merges) |
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

## Outcome
_Pending._
