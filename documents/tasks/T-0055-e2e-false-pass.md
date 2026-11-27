# T-0055: `tool/e2e_ios.sh` must fail a target whose app did not build (false PASS)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (verification tooling; negative controls required; ADR-0011) |
| Branch | `fleet/T-0055-e2e-false-pass` |
| Created | 2026-11-27 |
| Depends on | — |
| Related | T-0054 handoff (found it); ADR-0006 (e2e evidence); `tool/e2e_ios.sh`; protocol "Flaky tests" |

## Goal
The T-0054 engineer saw `tool/e2e_ios.sh` report PASS for two targets that did not compile. The Xcode build failed, and the app the previous target had installed ran its own test instead. Every e2e PASS in our evidence depends on this script, so it must never report a target as passing unless that target's own build ran.

## Scope
- **In:**
  - Reproduce the false PASS: a target with a compile error, run after a target that passes.
  - Root-cause why the runner's exit code is 0. Is it `flutter drive` behaviour, or how the script reads `rc`? Record the answer in a finding.
  - Fix it in depth. Both defences are needed:
    1. Before each target, uninstall the app from the simulator (`simctl uninstall <udid> <bundle id>`), so a stale build can never run.
    2. A target fails if its log contains a build-failure marker, whatever the exit code. At minimum: `BUILD FAILED`, `Error (Xcode)`, `Could not build the application`, `Error: Compilation failed`, and a Dart compile error line. Keep the list in one place and document it.
  - Add a positive identity check if it's cheap. For example, the target logs a marker naming its own file, and the script requires that marker.
  - Re-baseline: run the **full mini_client e2e suite on `origin/main`** with the fixed script on your own simulator. Report any target that now fails: it was a hidden false PASS.
- **Out:** Android, CI.

## Acceptance criteria
- **T-0055-AC1:** Repro and negative controls, all through the real script on your own simulator.
  - (a) A compile-error target after a passing target is FAIL, with the reason "build failed" in the summary.
  - (b) A compile-error target as the only target is FAIL.
  - (c) A target whose test fails at runtime is still FAIL.
  - (d) A good target is still PASS.
  - (e) With fix 1 alone and with fix 2 alone, (a) is still FAIL. Each defence works on its own.
- **T-0055-AC2:** Script tests. If the repo has shell tests for `e2e_ios.sh`, extend them. Otherwise add a fake `--runner-cmd` test that prints each marker with exit 0, and check that every marker yields FAIL. Name them `T-0055-AC2`.
- **T-0055-AC3:** Re-baseline. The full mini_client e2e on `origin/main` (latest at the time you run it) passes with the fixed script, or every failure is reported to the TL with its log. The summary goes in evidence.
- **T-0055-AC4:** Gates: `shellcheck` on the script if available, `test //...`, and the finding `F-0055-e2e-false-pass.md`. Update `tool/README.md` (e2e section).

## Log
- 2026-11-27: Created and dispatched (TL).
