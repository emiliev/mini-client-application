# T-0005: CI & quality gates

| Field | Value |
|---|---|
| Status | Blocked |
| Owner | crew: Engineer (worktree) |
| Branch | `fleet/T-0005-ci-quality-gates` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0003. Hosting is settled: GitHub (T-0006), so GitHub Actions is the natural CI platform |
| Related | ADR-0003 (review before integration) |

## Goal
Make quality checks automatic and identical for every crew member: locally first, then in CI once a remote exists.

## Scope
- **In (local, unblocked after T-0003):** a single entry point such as `make check` or `tool/check.sh` that runs format check, analyze and tests through `fvm`. Optional pre-commit hook.
- **In (CI):** a GitHub Actions workflow that runs the same entry point, with an ADR for the CI platform. The repo is private, so runs use the account's Actions minutes; cache the SDK and pub packages and keep jobs lean (F-0002).
- **Out:** release / distribution pipeline (P-005).

## Acceptance criteria
- [ ] One command runs every gate locally and fails on any violation.
- [ ] The Definition of Done in `fleet/protocol.md` references that command.
- [ ] CI runs on every push or PR and is green on `main`.

## Log
- 2026-11-22: Created. Blocked on T-0003 and Q-005.
- 2026-11-22: The hosting part of Q-005 is answered (GitHub, T-0006). Now blocked only on T-0003.

## Outcome
_Pending._
