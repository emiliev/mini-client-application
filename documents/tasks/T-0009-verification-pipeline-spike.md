# T-0009: Verification pipeline spike (iOS)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (background) |
| Branch | — (throwaway app in the TL scratchpad, outside the repo) |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | — |
| Related | ADR-0006, T-0005, T-0010, F-0004 |

## Goal
Prove, with exact working commands, that this Mac can run every verification layer in ADR-0006 for a Flutter iOS app, before the real project exists.

## Acceptance criteria
- **T-0009-AC1:** Given a throwaway Flutter iOS app, when the widget tests run, then they pass, and the commands and timings are recorded.
- **T-0009-AC2:** Given a golden test, when the UI changes, then the test fails and the location of the diff images is recorded.
- **T-0009-AC3:** Given `flutter test --coverage`, then `lcov.info` exists and a line-coverage % can be computed without extra tools.
- **T-0009-AC4:** Given a dedicated, agent-created simulator, when `integration_test` runs, then the e2e test passes; first-run and repeat-run times are recorded.
- **T-0009-AC5:** Given an e2e run, then PNG screenshots are captured both in-test and out-of-test, and an agent can view them and describe them correctly.
- **T-0009-AC6:** Given two agent-created simulators, then both can be booted at once (parallel Verifiers), and both are deleted afterwards.

## Constraints
No repo changes, no global installs, a dedicated simulator only, cleanup always, 25-minute timebox.

## Log
- 2026-11-22: Dispatched in the background, in parallel with the TL writing ADR-0006.

## Outcome
_Pending: becomes F-0004._
