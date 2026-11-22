# Project Status

_Last updated: 2026-11-22 by Tech Lead_

| | |
|---|---|
| **Product** | mini-client: a mobile-first **Marvel app** for **iOS & Android**, backed by an in-repo `mocked_backend` ([charter](project/charter.md)) |
| **Phase** | 0 — Inception: charter drafted, waiting for PO confirmation |
| **Health** | Amber: waiting on the PO tech stack ([Q-006](open-questions.md#q-006)) and MVP confirmation ([Q-008](open-questions.md#q-008)) |
| **Code** | None yet. The repo holds only documentation. |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private). `origin/main` is the integration branch ([ADR-0004](adr/0004-git-integration-workflow.md)). |
| **Active crew** | None. The Researcher finished T-0008. |

## Now
- [T-0002](tasks/T-0002-product-charter.md) Charter & MVP scope: **In Review** with the PO (Q-008)

## Next (in order, once unblocked)
1. [T-0004](tasks/T-0004-architecture-decision.md) Architecture & tech-stack ADRs (TL + Planner), as soon as Q-006 arrives
2. [T-0003](tasks/T-0003-flutter-project-scaffold.md) Flutter scaffold (crew: Engineer), in parallel with T-0004
3. [T-0005](tasks/T-0005-ci-quality-gates.md) CI & quality gates, and [T-0007](tasks/T-0007-mocked-backend-module.md) `mocked_backend` (two Engineers in parallel)
4. Feature tasks F1 to F5

## Blocked
| Item | Blocked on | Default if no answer |
|---|---|---|
| T-0003, T-0004 | Q-006 (PO tech stack, arriving next) | — |
| T-0002 acceptance | Q-008 (confirm F1 to F5) | build F1 to F5 as proposed |
| T-0005, T-0007 | T-0003 (and T-0004 for T-0007) | — |

## Recent decisions & findings
- [ADR-0004](adr/0004-git-integration-workflow.md) Git integration: the TL merges `--no-ff` and pushes `origin/main`
- [ADR-0005](adr/0005-mocked-backend-module.md) Mocked backend as an in-repo module behind a data-source interface
- [F-0003](findings/F-0003-marvel-api-unavailable.md) The official Marvel API is gone, so the mock contract is our own design

## Watch items
- [Q-004](open-questions.md#q-004): bundle id `com.emiliev.miniclinet`. Confirm the spelling (`miniclinet` vs `miniclient`) before the scaffold.
- [Q-007](open-questions.md#q-007) / [R-005](risks.md): a public store release of a Marvel-branded app needs licensing.

## Key facts for anyone joining
- Repo: the PO's checkout of `main` is at `/Users/emililiev/projects/flutter/mini-client`; fleet worktrees are under `/Users/emililiev/orca/workspaces/mini-client/`.
- Remote: `origin` over HTTPS with keychain auth. No SSH key, `gh` not logged in, so no PRs from the CLI ([F-0002](findings/F-0002-github-remote-access.md)).
- Toolchain: Flutter through FVM (global 3.41.0 / Dart 3.11.0). Always use `fvm flutter` ([F-0001](findings/F-0001-environment-survey.md)).
