# Project Status

_Last updated: 2026-11-22 by Tech Lead_

| | |
|---|---|
| **Phase** | 0 — Inception (documentation & direction) |
| **Health** | Amber: waiting on product direction ([Q-001](open-questions.md#q-001), [Q-002](open-questions.md#q-002), [Q-003](open-questions.md#q-003)) |
| **Code** | None yet. The repo holds only documentation. |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private) as `origin`. `main` is pushed; docs are on `fleet/T-0001-documentation-scaffold`, waiting to be merged ([P-008](pending-work.md)). |
| **Active crew** | None. Crew will be dispatched once T-0003 is unblocked. |

## Now
- [T-0001](tasks/T-0001-documentation-scaffold.md) Documentation scaffold & fleet protocol: **Done**
- [T-0006](tasks/T-0006-link-github-remote.md) Link GitHub remote: **Done**

## Next (in order, once unblocked)
1. [T-0002](tasks/T-0002-product-charter.md) Product charter & MVP scope (Tech Lead)
2. [T-0003](tasks/T-0003-flutter-project-scaffold.md) Flutter project scaffold (crew: Engineer)
3. [T-0004](tasks/T-0004-architecture-decision.md) Architecture & state-management ADR (Tech Lead + Planner); can run in parallel with T-0003
4. [T-0005](tasks/T-0005-ci-quality-gates.md) CI & quality gates (crew: Engineer); the hosting question is settled (GitHub)

## Blocked
| Item | Blocked on | Default if no answer |
|---|---|---|
| T-0002 | Q-001 (what the product is), Q-003 (backend) | none, needs PO input |
| T-0003 | Q-001 (app or package), Q-002 (platforms) | iOS + Android app |
| T-0005 | T-0003 | — |
| P-008 (merge docs into `main`) | Q-005 merge policy | — |

## Recent decisions
- [ADR-0001](adr/0001-record-architecture-decisions.md) Record architecture decisions
- [ADR-0002](adr/0002-documentation-as-code.md) Documentation as code in `documents/`
- [ADR-0003](adr/0003-fleet-operating-model.md) Fleet operating model

## Key facts for anyone joining
- Repo: main checkout at `/Users/emililiev/projects/flutter/mini-client`; fleet worktrees under `/Users/emililiev/orca/workspaces/mini-client/`.
- Remote: `origin` over HTTPS with keychain auth. No SSH key, `gh` not logged in, so no PRs from the CLI. See [F-0002](findings/F-0002-github-remote-access.md).
- Toolchain: Flutter through FVM (global 3.41.0 / Dart 3.11.0). Always use `fvm flutter`. See [F-0001](findings/F-0001-environment-survey.md).
