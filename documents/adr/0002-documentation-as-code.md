# ADR-0002: Documentation as code in `documents/`

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** Product Owner (requirement), Tech Lead (structure)
- **Related:** ADR-0001, ADR-0003, T-0001

## Context
The Product Owner requires the project to be fully documented in a `documents/` directory at the repo root: architecture diagrams, ADRs, tasks and their status, findings and pending work. The goal is that anyone, human or agent, can pick up the project without losing context.

## Options considered
1. **External tools** (Notion, Jira, Google Docs). Rejected: agents can't reliably read or write them, they drift from the code, and they aren't versioned with the code.
2. **Markdown in the repo, with diagrams as image files.** Rejected: images don't diff and go stale silently.
3. **Markdown in the repo, with Mermaid diagrams inline.** Chosen.

## Decision
- All project knowledge lives in `documents/` as Markdown, versioned with the code. The layout is in [documents/README.md](../README.md).
- Diagrams are Mermaid code blocks.
- Doc updates ship **in the same commit** as the work they describe.
- Each kind of document has a stable ID scheme (`T-`, `ADR-`, `F-`, `Q-`, `R-`, `P-`) and a template in `documents/templates/`.
- `STATUS.md` is the always-current entry point. `journal/` is the chronological log, one file per day.
- Root `CLAUDE.md` points every agent session at these docs and at the rules.

## Consequences
- **Positive:** context survives across sessions; history is in git; reviews cover docs and code together.
- **Negative:** discipline cost. Stale docs are worse than none, so the Tech Lead checks doc updates as part of every review ([Definition of Done](../fleet/protocol.md#definition-of-done)).
