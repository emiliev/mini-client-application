# T-XXXX: <Title>

| Field | Value |
|---|---|
| Status | Backlog / Ready / In Progress / In Verification / Blocked / Done / Dropped |
| Owner | Tech Lead / crew: <role> |
| Verifier | crew: Verifier (assigned at handoff; never the implementer) |
| Branch | `fleet/T-XXXX-<slug>` |
| Created | YYYY-MM-DD |
| Updated | YYYY-MM-DD |
| Depends on | T-…, Q-… |
| Related | ADR-…, F-… |

## Goal
Why this task exists, in one or two sentences.

## Scope
- **In:**
- **Out:**
- **Files / areas touched:** (lets the TL check for parallel overlap)

## Acceptance criteria
Written by the TL before dispatch, as Given / When / Then ([ADR-0006](../adr/0006-verification-strategy.md)). Each one needs a test whose name contains its ID, or a screenshot checkpoint if it's purely visual.

- **T-XXXX-AC1:** Given … When … Then …
- **T-XXXX-AC2:** Given … When … Then …

## Verification plan
| AC | Layer (L1 unit / L2 widget / L3 golden / L4 e2e / L5 visual) | Test name or checkpoint | Status |
|---|---|---|---|
| T-XXXX-AC1 | | | ☐ |

## Plan
1. …

## Log
Append-only, newest last.
- YYYY-MM-DD: …

## Outcome
Filled in at handoff and verification:
- **Changed:** files, branch, commits
- **Engineer evidence:** `tool/verify.sh` output summary
- **Verification:** report at `documents/evidence/T-XXXX/verification-report.md`, verdict PASS / FAIL
- **Review:** `/code-review` result
- **Decisions:** ADR-… (or none)
- **Findings:** F-… (or none)
- **Follow-ups:** for pending work, or new tasks
