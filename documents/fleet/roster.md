# Fleet Roster

_Owned by Tech Lead. Last updated 2026-11-22._

## Roles
| Role | Who | Responsibilities |
|---|---|---|
| **Product Owner** | Emil (human) | Vision, scope, priorities; publishing, spending, third-party accounts. Answers [open-questions.md](../open-questions.md). |
| **Tech Lead** | Claude, main session | Turns direction into tasks with Given/When/Then ACs; makes technical decisions (ADRs); dispatches crew; runs the merge gate (ADR-0006); merges and pushes `origin/main` (ADR-0004); owns STATUS, BOARD, journal and indexes. |
| Crew: **Planner** | `Plan` agent (read-only) | Implementation plans and architecture trade-off analysis for large tasks. |
| Crew: **Explorer** | `Explore` agent (read-only) | Codebase sweeps: locating code, mapping usages. |
| Crew: **Researcher** | `web-fetch` / `general-purpose` agent | Reads external docs (packages, platform guides) and reports conclusions as findings. |
| Crew: **Engineer** | `general-purpose` agent in an isolated worktree | Implements exactly one task on its own branch, with a test for every AC. Several can run in parallel on independent tasks. |
| Crew: **Verifier** | `general-purpose` agent, **fresh**, in its own worktree with its own simulator | Independently verifies a task branch: re-runs gates, audits tests against ACs, runs e2e, does visual acceptance with screenshots, writes the verification report. **Never the implementer** (ADR-0006). |
| Crew: **Reviewer** | `/code-review` | Correctness review of a task's diff before integration. |

Crew are dispatched when there is unblocked work. Idle agents are not kept running.

## Active assignments
| Crew member | Task | Branch | Dispatched | Status |
|---|---|---|---|---|
| Engineer (worktree) | T-0012 iOS simulator e2e runner | `fleet/T-0012-ios-sim-e2e-runner` | 2026-11-22 | In Progress |

## History
| Date | Crew member | Task | Result |
|---|---|---|---|
| 2026-11-22 | Tech Lead (self) | T-0001 | Done: documentation scaffold |
| 2026-11-22 | Tech Lead (self) | T-0006 | Done: GitHub remote linked |
| 2026-11-22 | Researcher (web-fetch, background) | T-0008 | Done: Marvel developer portal retired (F-0003) |
| 2026-11-22 | Tech Lead (self) | T-0002 | In Review: charter drafted, MVP proposed (Q-008) |
| 2026-11-22 | Engineer (background) | T-0009 | Done: pipeline proven in about 5 min; TL spot-check PASS (F-0004) |
