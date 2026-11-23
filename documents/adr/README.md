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
| [0004](0004-git-integration-workflow.md) | Git integration workflow | Accepted | 2026-11-22 |
| [0005](0005-mocked-backend-module.md) | Mocked backend as an in-repo module | Accepted (transport deferred) | 2026-11-22 |
| [0006](0006-verification-strategy.md) | Verification strategy (no merge without independent evidence) | Accepted (§2 coverage superseded by 0010) | 2026-11-22 |
| [0007](0007-tide-miniclient-architecture.md) | Adopt Tide's Project Miniclient ("Lego") architecture and stack | Accepted | 2026-11-23 |
| [0008](0008-bazel-with-ai-rules.md) | Build with Bazel using ai_rules_dart / ai_rules_flutter | Accepted | 2026-11-23 |
| [0009](0009-exemplar-first-generation-and-loc.md) | Exemplar-first code generation and the LOC metric | Accepted (LOC pending Q-010) | 2026-11-23 |
| [0010](0010-testing-tiers-and-coverage.md) | Tide testing tiers, BDD traceability, 90 % coverage | Accepted | 2026-11-23 |

## Expected upcoming ADRs
| Topic | Comes from |
|---|---|
| CI platform & gates (GitHub Actions scope, macOS minutes) | P4-19 / T-0005 successor |
| Per-experiment decisions that change `.bazelrc` or rules patches | P4 experiment cards |
| Native plugin probe approach (pods vs SwiftPM) | R26 |
