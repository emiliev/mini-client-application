# mini-client — Project Documentation

This directory is the **single source of truth** for the project: what we're building, why, how, what is in flight, and what we have learned. If it isn't written here, it didn't happen ([ADR-0002](adr/0002-documentation-as-code.md)).

## Start here
1. [STATUS.md](STATUS.md): where the project is right now. Read it first, every session.
2. [tasks/BOARD.md](tasks/BOARD.md): every task and its state.
3. [open-questions.md](open-questions.md): decisions waiting on the Product Owner.
4. [journal/](journal/): the latest entry says what happened last session and where to pick up.

## Map
| Area | Path | What lives there |
|---|---|---|
| Status dashboard | [STATUS.md](STATUS.md) | Phase, health, now / next / blocked |
| Project | [project/](project/) | [Charter](project/charter.md) (vision, goals, non-goals), [roadmap](project/roadmap.md), [glossary](project/glossary.md) |
| Architecture | [architecture/](architecture/) | [System overview](architecture/overview.md) and diagrams (Mermaid) |
| Decisions | [adr/](adr/README.md) | Architecture Decision Records and their index |
| Tasks | [tasks/](tasks/BOARD.md) | `BOARD.md` plus one file per task |
| Findings | [findings/](findings/README.md) | Investigations, spikes, gotchas, bugs found, lessons learned |
| Evidence | [evidence/](evidence/README.md) | Per-task verification reports and screenshots ([ADR-0006](adr/0006-verification-strategy.md)) |
| Pending work | [pending-work.md](pending-work.md) | Backlog not yet scoped into tasks, deferred items, tech debt |
| Open questions | [open-questions.md](open-questions.md) | Questions for the Product Owner, with defaults |
| Risks | [risks.md](risks.md) | Risk register |
| Fleet | [fleet/](fleet/) | [Roster & assignments](fleet/roster.md), [operating protocol](fleet/protocol.md) |
| Journal | [journal/](journal/) | Dated session log (one file per day) |
| Templates | [templates/](templates/) | Copy these to create new documents |

## Conventions
- **IDs** are never reused: `T-####` tasks, `ADR-####` decisions, `F-####` findings, `Q-###` questions, `R-###` risks, `P-###` pending items.
- **File names:** `<ID>-<kebab-slug>.md` (ADRs: `<####>-<slug>.md`).
- **Dates:** ISO `YYYY-MM-DD`.
- **Diagrams:** Mermaid in fenced code blocks, so they render on GitHub and in most IDEs and diff as text. Avoid binary images.
- **Link, don't duplicate:** refer to other docs by ID with a relative link.
- **Task status values:** `Backlog` → `Ready` → `In Progress` → `In Review` → `Done`, plus `Blocked` and `Dropped`.
- **Same-commit rule:** doc updates ship in the same commit as the work they describe.
- **Ownership:** see [CLAUDE.md](../CLAUDE.md). Crew edit their own task file; the Tech Lead owns the shared files.
