# T-0007: `mocked_backend` module

| Field | Value |
|---|---|
| Status | Backlog |
| Owner | crew: Engineer (worktree) |
| Branch | `fleet/T-0007-mocked-backend` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0003 (scaffold), T-0004 (layout, transport, models approach) |
| Related | ADR-0005, F-0003, Q-007, R-005, R-006 |

## Goal
Build the in-repo module that provides all of the app's data, behaving like a realistic backend (ADR-0005).

## Scope
- **In:**
  - A Dart package `mocked_backend`, at the path decided in T-0004.
  - An **own domain-first contract** (F-0003): characters, comics (and series and creators as F3 and F4 need), with paginated responses (offset, limit, total, count), name-prefix search, ordering, and detail-by-id with related collections.
  - A fixture dataset large enough to exercise pagination (on the order of 100+ characters and 100+ comics). Text is original or factual summaries; images are placeholders (R-005).
  - Simulated latency (configurable, zero in tests), injectable failures (timeout, server error, empty), deterministic output.
  - The contract documented in the package README, and the transport per the T-0004 ADR.
  - Unit tests covering pagination edges, search, not-found and failure injection.
- **Out:** app-side repositories and UI (feature tasks).
- **Files / areas touched:** the `mocked_backend` package only, plus a pubspec reference from the app.

## Acceptance criteria
- [ ] The package builds, analyzes clean and its tests pass under `fvm`.
- [ ] The contract is documented, and pagination, search and detail endpoints are covered by tests.
- [ ] Latency and failure injection can be configured from app code and tests.
- [ ] No copyrighted Marvel artwork in the repo (placeholder images only, unless Q-007 says otherwise).

## Log
- 2026-11-22: Created from the Q-003 answer and ADR-0005. Contract approach set by F-0003.

## Outcome
_Pending._
