# T-0003: Flutter project scaffold

| Field | Value |
|---|---|
| Status | Blocked |
| Owner | crew: Engineer (worktree) |
| Branch | `fleet/T-0003-flutter-scaffold` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | Q-001 (app or package), Q-002 (platforms); Q-004 non-blocking (placeholder org id) |
| Related | F-0001, R-004 |

## Goal
Create a clean, reproducible Flutter project skeleton that every worktree builds the same way.

## Scope
- **In:**
  - Pin the SDK with FVM (`fvm use <version>` → `.fvmrc`). The Tech Lead picks the version at dispatch and records it in a new ADR.
  - `fvm flutter create` with the agreed project type, platforms and org id (placeholder allowed, Q-004).
  - Strict lint config in `analysis_options.yaml`.
  - `.gitignore` that covers `.fvm/` SDK symlinks and build outputs.
  - Root `README.md` with setup and run instructions that use `fvm flutter`.
- **Out:** architecture and folder structure beyond the template (T-0004); CI (T-0005).

## Acceptance criteria
- [ ] `fvm flutter --version` inside the project resolves to the pinned SDK.
- [ ] `fvm flutter analyze` reports no issues.
- [ ] `fvm flutter test` passes.
- [ ] The app builds for at least one target platform (record which in the Outcome).
- [ ] ADR for SDK version & pinning is Accepted.
- [ ] README explains setup from a fresh clone.

## Plan
1. TL decides the SDK version and drafts the ADR.
2. Dispatch an Engineer in a worktree with the brief from the protocol.
3. Review, verify, integrate.

## Log
- 2026-11-22: Created. Blocked on Q-001 and Q-002.

## Outcome
_Pending._
