# Fleet Roster

_Owned by Tech Lead. Last updated 2026-11-22._

## Roles
| Role | Who | Responsibilities |
|---|---|---|
| **Product Owner** | Emil (human) | Vision, scope, priorities, outward-facing actions (pushing, publishing, spending). Answers [open-questions.md](../open-questions.md). |
| **Tech Lead** | Claude, main session | Turns direction into tasks; makes technical decisions (ADRs); dispatches, reviews and integrates crew work; owns STATUS, BOARD, journal and indexes. |
| Crew: **Planner** | `Plan` agent (read-only) | Implementation plans and architecture trade-off analysis for large tasks. |
| Crew: **Explorer** | `Explore` agent (read-only) | Codebase sweeps: locating code, mapping usages. |
| Crew: **Researcher** | `web-fetch` / `general-purpose` agent | Reads external docs (packages, platform guides) and reports conclusions as findings. |
| Crew: **Engineer** | `general-purpose` agent in an isolated worktree | Implements exactly one task on its own branch. Several can run in parallel on independent tasks. |
| Crew: **Reviewer** | `/code-review` | Correctness review of a task branch before integration. |

Crew are dispatched when there is unblocked work. Idle agents are not kept running.

## Active assignments
| Crew member | Task | Branch | Dispatched | Status |
|---|---|---|---|---|
| — | — | — | — | No crew dispatched yet: all remaining tasks are blocked on direction (see [STATUS](../STATUS.md)) |

## History
| Date | Crew member | Task | Result |
|---|---|---|---|
| 2026-11-22 | Tech Lead (self) | T-0001 | Done: documentation scaffold |
| 2026-11-22 | Tech Lead (self) | T-0006 | Done: GitHub remote linked |
