# T-0001: Documentation scaffold & fleet protocol

| Field | Value |
|---|---|
| Status | Done |
| Owner | Tech Lead |
| Branch | `continue-previous-work` (Orca session branch), fast-forwarded into `main` 2026-11-22 (P-008) |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | — |
| Related | ADR-0001, ADR-0002, ADR-0003, F-0001 |

## Goal
Give the project a documentation system that lets anyone, human or agent, track progress and pick up work without losing context. Set up the fleet operating model.

## Scope
- **In:** the `documents/` structure, templates, initial ADRs, the task board, findings log, pending work, open questions, risk register, fleet roster and protocol, journal, and root `CLAUDE.md`.
- **Out:** any application code (T-0003) and product definition (T-0002).

## Acceptance criteria
- [x] `documents/` exists with an index (README), a status dashboard, and sections for architecture, ADRs, tasks, findings, pending work, open questions, risks, fleet and journal.
- [x] Templates for tasks, ADRs, findings and journal entries.
- [x] ADRs recording the documentation and fleet decisions.
- [x] Root `CLAUDE.md` directs every agent session to the docs and rules.
- [x] Environment surveyed and recorded as a finding.
- [x] Open direction questions recorded for the PO.

## Log
- 2026-11-22: Surveyed repo and toolchain (F-0001). Created the documentation structure, ADR-0001 to ADR-0003, tasks T-0001 to T-0005, Q-001 to Q-006, R-001 to R-004, P-001 to P-008, and CLAUDE.md.
- 2026-11-22: Branch pushed to `origin` as `fleet/T-0001-documentation-scaffold` (T-0006).

## Outcome
- **Changed:** added `CLAUDE.md` and `documents/**`. Committed on `continue-previous-work`.
- **Verified:** every relative link in the docs points to an existing file (checked with a script); Mermaid blocks follow standard syntax.
- **Follow-ups:** P-008 (integrate this branch into `main`, waiting on the Q-005 policy).
