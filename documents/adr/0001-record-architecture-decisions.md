# ADR-0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** Tech Lead
- **Related:** ADR-0002, T-0001

## Context
The project is built by several AI agent sessions over time. No single session keeps its memory, so the reasoning behind decisions gets lost unless it is written down. People joining later need to know why the code is the way it is.

## Options considered
1. **No formal record.** Decisions live in commit messages and chat. Rejected: chat context is lost between sessions, and commit messages are too narrow.
2. **One big design doc.** Rejected: it goes stale and mixes current state with history.
3. **ADRs, a lightweight MADR-style format with one file per decision.** Chosen.

## Decision
Record every significant decision as an ADR in `documents/adr/` using [the template](../templates/adr.md). ADRs are numbered sequentially, never renumbered, and immutable once Accepted. Changes come as superseding ADRs.

## Consequences
- **Positive:** new sessions and crew can rebuild the "why" quickly; decisions get a deliberate moment of review.
- **Negative:** a small writing overhead per decision.
- **Follow-up:** the Tech Lead keeps [the index](README.md) current.
