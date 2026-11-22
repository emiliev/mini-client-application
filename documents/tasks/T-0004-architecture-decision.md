# T-0004: Architecture & state-management decision

| Field | Value |
|---|---|
| Status | Blocked |
| Owner | Tech Lead, with crew: Planner (and Researcher if needed) |
| Branch | `fleet/T-0004-architecture` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0002 (charter); Q-006 non-blocking (TL decides if no preference) |
| Related | [architecture/overview.md](../architecture/overview.md) |

## Goal
Decide and document how the code is structured, so feature work follows one consistent pattern.

## Scope
- **In:** ADRs for layering / folder structure, state management, navigation, DI, and error handling. Fill in sections 2 to 4 of `architecture/overview.md` with Mermaid diagrams. Optionally a thin reference implementation of one feature slice.
- **Out:** feature work.

## Acceptance criteria
- [ ] ADRs Accepted for architecture & layering, state management and navigation.
- [ ] `architecture/overview.md` sections 2 to 4 have real diagrams, with no TBD left for the decided items.
- [ ] Dependency rules between layers are written down and, where possible, enforceable (lint or import rules).

## Plan
1. A Planner agent compares options against the charter's needs.
2. TL decides and writes the ADRs.
3. Optional: an Engineer builds a reference slice on the scaffold from T-0003.

## Log
- 2026-11-22: Created. Blocked on T-0002.

## Outcome
_Pending._
