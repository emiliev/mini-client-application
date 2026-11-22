# Project Status

_Last updated: 2026-11-22 by Tech Lead_

| | |
|---|---|
| **Product** | mini-client: a mobile-first **Marvel app** for **iOS & Android**, backed by an in-repo `mocked_backend` ([charter](project/charter.md)) |
| **Phase** | 0 — Inception: charter drafted; verification strategy set |
| **Health** | Amber: waiting on the PO tech stack ([Q-006](open-questions.md#q-006)) and MVP confirmation ([Q-008](open-questions.md#q-008)) |
| **Code** | None yet. The repo holds only documentation. |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private). `origin/main` is the integration branch ([ADR-0004](adr/0004-git-integration-workflow.md)). |
| **Merge gate** | Nothing merges without a PASS from a fresh Verifier, a clean review, and the TL re-verifying the merge result ([ADR-0006](adr/0006-verification-strategy.md)) |
| **Active crew** | Engineer (background) on [T-0009](tasks/T-0009-verification-pipeline-spike.md), the iOS verification pipeline spike |

## Now
- [T-0009](tasks/T-0009-verification-pipeline-spike.md) Verification pipeline spike: **In Progress**
- [T-0002](tasks/T-0002-product-charter.md) Charter & MVP scope: **In Review** with the PO (Q-008)

## Next (in order, once unblocked)
1. [T-0004](tasks/T-0004-architecture-decision.md) Architecture & tech-stack ADRs (TL + Planner), as soon as Q-006 arrives
2. [T-0003](tasks/T-0003-flutter-project-scaffold.md) Flutter scaffold (crew: Engineer), in parallel with T-0004
3. In parallel after T-0003: [T-0005](tasks/T-0005-ci-quality-gates.md) `tool/verify.sh` + CI, [T-0010](tasks/T-0010-e2e-visual-harness.md) e2e + screenshot harness, and [T-0007](tasks/T-0007-mocked-backend-module.md) `mocked_backend`
4. Feature tasks F1 to F5, each with a per-feature e2e journey; then [T-0011](tasks/T-0011-mvp-journey-e2e.md), the full MVP journey and visual sign-off

## Blocked
| Item | Blocked on | Default if no answer |
|---|---|---|
| T-0003, T-0004 | Q-006 (PO tech stack, arriving next) | — |
| T-0002 acceptance | Q-008 (confirm F1 to F5) | build F1 to F5 as proposed |
| T-0005, T-0010 | T-0003, T-0009 | — |
| T-0007 | T-0003, T-0004 | — |
| Local Android verification | Q-009 (Android toolchain) | Android verified in CI only |

## Recent decisions & findings
- [ADR-0006](adr/0006-verification-strategy.md) Verification strategy: Given/When/Then ACs mapped to tests, layers L0 to L5, a fresh Verifier, evidence in `documents/evidence/`
- [ADR-0004](adr/0004-git-integration-workflow.md) Git integration: the TL merges `--no-ff` and pushes `origin/main` (PO confirmed)
- [ADR-0005](adr/0005-mocked-backend-module.md) Mocked backend as an in-repo module behind a data-source interface
- [F-0003](findings/F-0003-marvel-api-unavailable.md) The official Marvel API is gone, so the mock contract is our own design

## Watch items
- [Q-004](open-questions.md#q-004): bundle id `com.emiliev.miniclinet`. Confirm the spelling (`miniclinet` vs `miniclient`) before the scaffold.
- [Q-007](open-questions.md#q-007) / [R-005](risks.md): a public store release of a Marvel-branded app needs licensing.
- [Q-009](open-questions.md#q-009) / [R-009](risks.md): no Android SDK on this Mac.

## Key facts for anyone joining
- Repo: the PO's checkout of `main` is at `/Users/emililiev/projects/flutter/mini-client`; fleet worktrees are under `/Users/emililiev/orca/workspaces/mini-client/`.
- Remote: `origin` over HTTPS with keychain auth. No SSH key, `gh` not logged in, so no PRs from the CLI ([F-0002](findings/F-0002-github-remote-access.md)).
- Toolchain: Flutter through FVM (global 3.41.0 / Dart 3.11.0). Always use `fvm flutter` ([F-0001](findings/F-0001-environment-survey.md)).
- iOS verification: Xcode 26.2, CocoaPods 1.16.2, simulator runtimes iOS 18.2 / 26.0 / 26.2. No Android SDK.
