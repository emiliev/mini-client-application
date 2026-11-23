# T-0017: Workspace skeleton, architecture guard, `mc_prelude` and `mc_di` (P1-01 + P1-02)

| Field | Value |
|---|---|
| Status | Ready for Verification |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0017-foundation`, **based on `eba44d8` (T-0014 head)**; rebased onto `main` after T-0014 merges |
| Created | 2026-11-23 |
| Depends on | T-0014 (Bazel workspace files, `tool/bazelw`) |
| Related | [plan 01 §2, §3, §7, P1-01, P1-02](../plan/01-architecture-and-modules.md), ADR-0007, R4, R15, R17, [tide-core research](../research/tide-miniclient/architecture-core.md) §4.1 to §4.3 |

## Goal
The first real app code on `main`: the Lego workspace layout, the architecture guard that enforces Tide's layer rules, and the two foundation utilities everything else depends on. Everything is built and tested by Bazel.

## Scope
- **In:**
  - Root pub workspace (`pubspec.yaml` with `workspace:`, `resolution: workspace` members, third-party-only lock, R10).
  - `utility/mc_analysis`: the shared lints. Tide's `tide_analysis` plus the plan 01 rules; generated files excluded.
  - `tool/mc_arch_check`: a Dart CLI enforcing utility→utility, feature→utility, no feature→feature, barrel-only imports (no `package:x/src/`), and R4/R15 barrel rules.
  - `utility/mc_prelude`: the `Result<S, F>` type, with every member from the article plus `fromAsync` and `guard`.
  - `utility/mc_di`: the get_it facade. It provides `McDIInitializer` (Tide's `TideDIInitializer`), `initializeDIContainer`, `diContainer<T>()`, child containers with `RootImport<T>` (R17) and `resetDIContainer()` for tests.
  - Hand-written `BUILD.bazel` per package (`dart_library` for pure Dart, `dart_test`); `mcgen buildgen` replaces these later.
- **Out:** injectable codegen (P3-04), other utilities, features.
- **Files / areas:** root `pubspec.yaml`, `utility/mc_analysis/`, `utility/mc_prelude/`, `utility/mc_di/`, `tool/mc_arch_check/`, `tool/mc_arch_check/test/fixtures/`.

## Acceptance criteria
- **T-0017-AC1** (P1-01 AC1): Given a fixture where a feature imports another feature's barrel, when `mc_arch_check` runs, then it exits 1 naming the `feature → feature` edge. Likewise for utility → feature.
- **T-0017-AC2** (P1-01 AC2): Given `package:x/src/…` imported from another package, then it fails with "barrel-only".
- **T-0017-AC3** (P1-01 AC4): Given a fixture violating each lint rule `mc_analysis` enables beyond the defaults, when analysed with `mc_analysis`, then each rule reports. List the rules and their source (Tide article or plan 01) in the package README.
- **T-0017-AC4** (P1-01 AC5, AC6): Given a feature barrel exporting a page, bloc or DI initializer, then `mc_arch_check` fails naming the symbol (R4). Given a route library importing a feature barrel, then it fails (R15).
- **T-0017-AC5** (P1-02 AC1, AC2, AC6): Every `Result` member has a passing unit test. `fromAsync` over a thrown `Error`, and `guard` over a `TypeError`, keep the message.
- **T-0017-AC6** (P1-02 AC3): Given two initializers, when `initializeDIContainer` runs, then they run in order and `diContainer<T>()` resolves both. Given the second throws, then nothing is published, and a retry registers each type exactly once.
- **T-0017-AC7** (P1-02 AC4, AC5): A child container with `RootImport<Foo>` resolves `Foo` to the root singleton, and child-only types are invisible at the root. `resetDIContainer()` in setUp isolates tests; production init never resets.
- **T-0017-AC8:** Given the merged tree, when `tool/bazelw test //utility/... //tool/mc_arch_check/...` runs with the analyze aspect, then all pass, and `mc_arch_check` passes on the real repo.

Tests are named with their AC IDs (ADR-0006). The utilities get solitary unit tests (ADR-0010).

## Log
- 2026-11-23: Created and dispatched in parallel with T-0014's fix round (PO asked for app code to start sooner).
- 2026-11-23: Engineer: rebased onto `origin/main` (e18ade6). Built `mc_analysis`, `mc_prelude`, `mc_di`, `mc_arch_check`; all hand-written `BUILD.bazel`; `tool/bazelw test //...` passes with the analyze aspect.

## Outcome
Done. Commits on `fleet/T-0017-foundation`. Evidence in `documents/evidence/T-0017/engineer/`.

### AC to test map
| AC | Test (all pass) |
|---|---|
| AC1 | `tool/mc_arch_check/test/arch_check_test.dart`: `T-0017-AC1 ...` (3 tests; fixtures `feature_to_feature`, `utility_to_feature`, `ok`) |
| AC2 | same file: `T-0017-AC2 ...` (2 tests; fixture `src_import`) |
| AC3 | `utility/mc_analysis/test/lints_test.dart`: `T-0017-AC3 ...` (5 tests; one fixture per rule; list and sources in `utility/mc_analysis/README.md`) |
| AC4 | arch_check_test: `T-0017-AC4 ...` (3 tests: R4 symbols, R15 route import, `RouteTargets` non-Flow return) |
| AC5 | `utility/mc_prelude/test/result_test.dart`: `T-0017-AC5 ...` (18 tests, every member incl. `guard`, `fromAsync` over `StateError`, `guard` over `TypeError`) |
| AC6 | `utility/mc_di/test/di_container_test.dart`: `T-0017-AC6 ...` (4 tests: order, param/name, throw then retry, dispose on failure) |
| AC7 | same file: `T-0017-AC7 ...` (8 tests: RootImport, named, missing import names T, child dispose, reset isolation, no second init) |
| AC8 | `tool/bazelw test //...` (analyze aspect on): 5/5 pass; `tool/bazelw run //tool/mc_arch_check:bin` prints OK on the repo (logs in evidence) |

### Notes and deviations
- `mc_analysis` has 20 Tide rules, not 22, plus `strict-inference`: `unnecessary_await_in_return` (deprecated) and `package_prefixed_library_names` (no-op) dropped, see F-0013.
- Root files touched: `pubspec.yaml` (members), `pubspec.lock` (additions only), `BUILD.bazel` (`//:options` deps = `//utility/mc_analysis`), `analysis_options.yaml` (now includes `mc_analysis`). `spike/hello` got `package:` imports (three lines) to satisfy `always_use_package_imports`.
- `initializeDIContainer` is transactional via a staging `GetIt`; a second call after success throws (no production reset).
- `Result.guard` is async and takes `F Function(Object error)`; `fromAction` also keeps `Error` messages.
- `mc_arch_check` is not itself a Bazel test over the real repo (needs the whole tree as data); it is run with `bazel run //tool/mc_arch_check:bin`. A `verify.sh` hook is a follow-up.
- No `Optional` (out of scope).
