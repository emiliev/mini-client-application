# T-0004: Architecture & tech-stack decisions

| Field | Value |
|---|---|
| Status | Superseded 2026-11-23: see [BOARD](BOARD.md#superseded-by-the-enterprise-plan-2026-11-23) |
| Owner | Tech Lead, with crew: Planner (and Researcher if needed) |
| Branch | `fleet/T-0004-architecture` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | Q-006 (PO architecture & tech stack, arriving next); T-0002 (charter drafted) |
| Related | [architecture/overview.md](../architecture/overview.md), ADR-0005, F-0003 |

## Goal
Turn the PO's tech stack into recorded decisions and a documented structure, so feature work follows one consistent pattern.

## Scope
- **In:** ADRs for repo layout & workspace (app + `mocked_backend`), layering, state management, navigation, DI, persistence (favorites), error handling, and the `mocked_backend` transport (deferred from ADR-0005). Fill in sections 2 to 4 of `architecture/overview.md` with Mermaid diagrams. Optionally a thin reference slice of one feature.
- **Out:** feature work; building the mock dataset (T-0007).

## Acceptance criteria
- [ ] Every item of the PO stack (Q-006) is captured in an Accepted ADR or explicitly mapped to one.
- [ ] ADRs Accepted for repo layout, layering, state management, navigation and `mocked_backend` transport.
- [ ] `architecture/overview.md` sections 2 to 4 have real diagrams, with no TBD left for the decided items.
- [ ] Dependency rules between layers are written down and, where possible, enforceable (lint or import rules).

## Plan
1. Record the PO stack verbatim in Q-006.
2. A Planner agent maps it onto the charter's needs (F1 to F5, ADR-0005) and flags gaps.
3. TL writes the ADRs and diagrams.
4. Optional: an Engineer builds a reference slice on the T-0003 scaffold.

## Log
- 2026-11-22: Created. Blocked on T-0002.
- 2026-11-22: Charter drafted. The PO will share the stack next (Q-006), which is now the blocker.

## Superseded
2026-11-23: replaced by the enterprise plan. See [plan/README.md §6](../plan/README.md#6-superseded-and-rescoped-tasks).

## Outcome
_Pending._
