# T-0010: E2E & visual verification harness (iOS)

| Field | Value |
|---|---|
| Status | Superseded 2026-11-23: see [BOARD](BOARD.md#superseded-by-the-enterprise-plan-2026-11-23) |
| Owner | crew: Engineer (worktree) |
| Verifier | crew: Verifier |
| Branch | `fleet/T-0010-e2e-harness` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0003 (scaffold), T-0012 (`tool/e2e_ios.sh` runner). Commands proven by T-0009 ([F-0004](../findings/F-0004-ios-verification-pipeline.md)) |
| Related | ADR-0006 (L4, L5), T-0005 (`tool/verify.sh`), T-0011 |

## Goal
Give every Engineer and Verifier one command that runs the app's e2e journeys on a dedicated iOS simulator and drops screenshots into the task's evidence folder.

## Scope
- **In:**
  - `integration_test` set up in the app, with an app entry point for tests that wires `mocked_backend` deterministically (zero latency, fixed seed).
  - Wire the app into `tool/e2e_ios.sh` from [T-0012](T-0012-ios-sim-e2e-runner.md). Don't reimplement the simulator lifecycle; add the app's `test_driver/integration_test.dart` (screenshot driver) and journey files.
  - A screenshot helper for tests, e.g. `checkpoint('name')`, that names files consistently.
  - A smoke e2e test (app launches, home renders) as the first journey.
  - README section: how to run e2e, how to read evidence.
- **Out:** feature journeys (each feature task adds its own); Android e2e (Q-009); golden setup (T-0005).

## Acceptance criteria
- **T-0010-AC1:** Given a clean checkout, when `tool/e2e_ios.sh T-0010` runs, then the smoke journey passes on a freshly created simulator and the script exits 0.
- **T-0010-AC2:** Given the run in AC1, then `documents/evidence/T-0010/` contains at least one PNG of ≤ 1200 px showing the app's home screen.
- **T-0010-AC3:** Given the e2e test fails or the script is interrupted, then the created simulator is still deleted (`xcrun simctl list` shows no `mc-T-0010-*`).
- **T-0010-AC4:** Given two runs with different task IDs started at the same time, then both pass without interfering.

## Verification plan
| AC | Layer | Test / checkpoint | Status |
|---|---|---|---|
| T-0010-AC1 | L4 | `smoke_test.dart` "T-0010-AC1 app launches to home" | ☐ |
| T-0010-AC2 | L5 | `home` checkpoint screenshot | ☐ |
| T-0010-AC3 | script | Verifier kills the run mid-way and checks the simulator list | ☐ |
| T-0010-AC4 | script | Verifier runs two in parallel | ☐ |

## Log
- 2026-11-22: Created from ADR-0006. Waiting on T-0003 and the T-0009 results.
- 2026-11-22: T-0009 done. Script design is based on the proven F-0004 commands. Waiting only on T-0003.
- 2026-11-22: The stack-independent runner script was split out into T-0012 (started now). T-0010 now wires the real app into it.

## Superseded
2026-11-23: replaced by the enterprise plan. See [plan/README.md §6](../plan/README.md#6-superseded-and-rescoped-tasks).

## Outcome
_Pending._
