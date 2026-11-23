# T-0014: Toolchain bring-up under Bazel (P3-01, spike S1)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Opus, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0014-toolchain` |
| Created | 2026-11-23 |
| Depends on | — (Phase A, wave A1) |
| Related | [plan 03 §1, §2, §4.5, §8, P3-01](../plan/03-bazel-integration.md), ADR-0008, R16, R18, R28, V3-01 |

## Goal
Prove the pinned toolchain works end to end on this Mac: a Flutter iOS hello-world built and tested by Bazel with `ai_rules_dart` `e7163aa` and `ai_rules_flutter` `876e263`, on Flutter 3.47.7 and Bazel 9.3.0. Also settle the two codegen unknowns: freezed `when` (R16) and go_router_builder over a Flutter closure (V3-01).

## Scope
- **In:** `MODULE.bazel`, `.bazelrc` (configs `sim`, `lint`, `ci`, `cold`, `budget16`, `profile`, `remote-cache`, following plan 03 §1), `.bazelversion`, `REPO.bazel`, `tool/bazelw`, `.fvmrc` (3.47.7), `spike/hello/` (app, widget test, freezed union, one `@TypedGoRoute` file), the build_runner overlay used only to produce reference outputs, and the `.gitignore` entries.
- **Out:** patch queue (T-0015+ / P3-02), unsupported shims (P3-03 to P3-05), real packages.
- **Files / areas:** repo root Bazel files, `tool/bazelw`, `spike/`.

## Acceptance criteria
- **T-0014-AC1:** Given a clean clone, when `tool/bazelw build --config=sim //spike/hello:hello_ios` runs, then it succeeds on Bazel 9.3.0 and the app launches on a private `mc-T-0014-*` simulator via `tool/e2e_ios.sh` or `simctl` (screenshot in evidence).
- **T-0014-AC2:** Given the same, when `tool/bazelw test //spike/hello:widget_test` runs, then it passes with the analyze aspect on.
- **T-0014-AC3:** Then the evidence records the bundled Dart version, a `.koutline` that stays byte-identical after a body-only edit, and no stripper-fallback diagnostic (H-SDK).
- **T-0014-AC4:** Given the sim build and a host test in one server, then the execution log counts any `DartKernel` or `DartCodegen` actions duplicated across configurations (H-CFGDUP), and the evidence records the count.
- **T-0014-AC5:** `fvm flutter --version` inside the repo reports 3.47.7.
- **T-0014-AC6:** Given a freezed union with private cases, when built with the stock freezed shim, then the `.freezed.dart` contains `when`/`maybeWhen`/`map` and a widget calling `state.when` compiles. Otherwise the `switch` fallback is recorded (R16).
- **T-0014-AC7:** Given one `@TypedGoRoute` file over real go_router 17.5.0 in a Flutter closure, when built with the stock go_router shim, then the `.g.dart` compiles and equals build_runner's output from the overlay. If it doesn't, the failure is recorded as a finding and go_router_builder joins the R28 fallback (V3-01).
- **T-0014-AC8:** Given `--config=lint`, `--config=ci --config=cold` and `--config=budget16`, when each parses (`tool/bazelw build --nobuild //spike/...`), then Bazel reports no unknown option or config.

## Log
- 2026-11-23: Created and dispatched (wave A1).

## Outcome
_Pending._
