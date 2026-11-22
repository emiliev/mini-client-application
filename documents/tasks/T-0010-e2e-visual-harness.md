# T-0010: E2E & visual verification harness (iOS)

| Field | Value |
|---|---|
| Status | Blocked |
| Owner | crew: Engineer (worktree) |
| Verifier | crew: Verifier |
| Branch | `fleet/T-0010-e2e-harness` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0003 (scaffold). Commands proven by T-0009 ([F-0004](../findings/F-0004-ios-verification-pipeline.md)) |
| Related | ADR-0006 (L4, L5), T-0005 (`tool/verify.sh`), T-0011 |

## Goal
Give every Engineer and Verifier one command that runs the app's e2e journeys on a dedicated iOS simulator and drops screenshots into the task's evidence folder.

## Scope
- **In:**
  - `integration_test` set up in the app, with an app entry point for tests that wires `mocked_backend` deterministically (zero latency, fixed seed).
  - `tool/e2e_ios.sh <task-id> [--device "iPhone 17 Pro"] [--runtime iOS-26-2]`: `xcrun simctl create mc-<task>-<role>` (never clone), `simctl boot` + `simctl bootstatus -b`, runs `SCREENSHOT_DIR=… fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<journey>_test.dart -d $UDID` (the driver uses `integrationDriver(onScreenshot:)`), downscales screenshots only when taller than 1200 px into `documents/evidence/<task>/`, and **always** deletes the simulator (`trap` on EXIT/INT/TERM). Expect about 45 s cold and about 15 s warm per journey (F-0004).
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

## Outcome
_Pending._
