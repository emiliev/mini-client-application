# Architecture Decision Records

An ADR captures **one** significant decision: the context, the options weighed, the choice, and its consequences. ADRs are immutable once Accepted. To change a decision, write a new ADR that supersedes the old one and update the old one's status line.

**Write an ADR when** a decision is costly to reverse, affects more than one feature, or someone will later ask "why did we do it this way?"

**Process:** copy [../templates/adr.md](../templates/adr.md) to `NNNN-<slug>.md` using the next free number. A crew member opens it as `Proposed`; the Tech Lead accepts it (or the Product Owner, for product-level decisions). Then add it to the index below.

## Index
| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-11-22 |
| [0002](0002-documentation-as-code.md) | Documentation as code in `documents/` | Accepted | 2026-11-22 |
| [0003](0003-fleet-operating-model.md) | Fleet operating model | Accepted | 2026-11-22 |

## Expected upcoming ADRs
| Topic | Comes from |
|---|---|
| Flutter SDK version & pinning (`.fvmrc`) | T-0003 |
| App architecture & layering | T-0004 |
| State management | T-0004 |
| Navigation / routing | T-0004 |
| Networking & API client | after Q-003 |
| Testing strategy | P-001 |
| CI platform & quality gates | T-0005 |
