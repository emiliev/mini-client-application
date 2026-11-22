# Project Status

_Last updated: 2026-11-22 by Tech Lead_

| | |
|---|---|
| **Phase** | 0 — Inception (documentation & direction) |
| **Health** | Amber: waiting on product direction ([Q-001](open-questions.md#q-001), [Q-002](open-questions.md#q-002), [Q-003](open-questions.md#q-003)) |
| **Code** | None yet. The repo holds only documentation. |
| **Active crew** | None. Crew will be dispatched once T-0003 is unblocked. |

## Now
- [T-0001](tasks/T-0001-documentation-scaffold.md) Documentation scaffold & fleet protocol: **Done**

## Next (in order, once unblocked)
1. [T-0002](tasks/T-0002-product-charter.md) Product charter & MVP scope (Tech Lead)
2. [T-0003](tasks/T-0003-flutter-project-scaffold.md) Flutter project scaffold (crew: Engineer)
3. [T-0004](tasks/T-0004-architecture-decision.md) Architecture & state-management ADR (Tech Lead + Planner); can run in parallel with T-0003
4. [T-0005](tasks/T-0005-ci-quality-gates.md) CI & quality gates (crew: Engineer)

## Blocked
| Item | Blocked on | Default if no answer |
|---|---|---|
| T-0002 | Q-001 (what the product is), Q-003 (backend) | none, needs Product Owner input |
| T-0003 | Q-001 (app or package), Q-002 (platforms) | iOS + Android app |
| T-0005 (CI part) | Q-005 (git remote / hosting) | local quality gates only |

## Recent decisions
- [ADR-0001](adr/0001-record-architecture-decisions.md) Record architecture decisions
- [ADR-0002](adr/0002-documentation-as-code.md) Documentation as code in `documents/`
- [ADR-0003](adr/0003-fleet-operating-model.md) Fleet operating model

## Key facts for anyone joining
- Repo: main checkout at `/Users/emililiev/projects/flutter/mini-client`; fleet worktrees under `/Users/emililiev/orca/workspaces/mini-client/`. No git remote yet.
- Toolchain: Flutter through FVM (global 3.41.0 / Dart 3.11.0). Always use `fvm flutter`. See [F-0001](findings/F-0001-environment-survey.md).
