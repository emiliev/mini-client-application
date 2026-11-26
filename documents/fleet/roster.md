# Fleet Roster

_Owned by Tech Lead. Last updated 2026-11-26._

## Roles
| Role | Who | Responsibilities |
|---|---|---|
| **Product Owner** | Emil (human) | Vision, scope, priorities; publishing, spending, third-party accounts. Answers [open-questions.md](../open-questions.md). |
| **Tech Lead** | Claude (Opus), main session | Turns direction into tasks with Given/When/Then ACs; makes technical decisions (ADRs); dispatches crew; runs the merge gate (ADR-0006); merges and pushes `origin/main` (ADR-0004); owns STATUS, BOARD, journal and indexes. |
| Crew: **Planner** | `Plan` agent (read-only) | Implementation plans and architecture trade-off analysis for large tasks. |
| Crew: **Explorer** | `Explore` agent (read-only) | Codebase sweeps: locating code, mapping usages. |
| Crew: **Researcher** | `web-fetch` / `general-purpose` agent | Reads external docs (packages, platform guides) and reports conclusions as findings. |
| Crew: **Engineer** | `general-purpose` agent in an isolated worktree. **Sonnet** by default; **Opus** for rules/codegen patches, vendored code, first exemplars, high-risk tasks (ADR-0011) | Implements exactly one task on its own branch, with a test for every AC. Several can run in parallel on independent tasks. |
| Crew: **Verifier** | `general-purpose` agent, **fresh**, in its own worktree with its own simulator. **Opus** tier for high-risk work, **Sonnet** tier otherwise; Sonnet for narrow re-verifications (ADR-0011) | Independently verifies a task branch: re-runs gates, audits tests against ACs, runs e2e, does visual acceptance with screenshots, writes the verification report. **Never the implementer** (ADR-0006). |
| Crew: **Reviewer** | `/code-review` (Opus, TL fork, medium) | Correctness review of a task's diff, **before** the Verifier (ADR-0011). |
| Crew: **Mechanic** | `general-purpose` agent, **Haiku** | Mechanical work only: bulk generated modules, lock re-resolution and merges, e2e re-runs, evidence and index chores. Never verifies, never changes behaviour tests. |

Crew are dispatched when there is unblocked work. Idle agents are not kept running.

## Active assignments
| Crew member | Task | Branch | Dispatched | Status |
|---|---|---|---|---|
| Engineer (Sonnet) | T-0039 auth slice (fix round) | `fleet/T-0039-session-and-auth` | 2026-11-26 | Paused: weekly limit until 2026-12-02 |
| Verifier (Opus) | T-0040 DS navigation (re-verification) | `fleet/T-0040-ds-navigation` | 2026-11-26 | Paused: weekly limit until 2026-12-02 |

## History
| Date | Crew member | Task | Result |
|---|---|---|---|
| 2026-11-22 | Tech Lead (self) | T-0001 | Done: documentation scaffold |
| 2026-11-22 | Tech Lead (self) | T-0006 | Done: GitHub remote linked |
| 2026-11-22 | Researcher (web-fetch, background) | T-0008 | Done: Marvel developer portal retired (F-0003) |
| 2026-11-22 | Tech Lead (self) | T-0002 | In Review: charter drafted, MVP proposed (Q-008) |
| 2026-11-22 | Engineer (background) | T-0009 | Done: pipeline proven in about 5 min; TL spot-check PASS (F-0004) |
| 2026-11-23 | Engineer (Opus, worktree) | T-0012 | Done: 7 ACs + 10 review fixes, suite 13/13 |
| 2026-11-23 | Verifier (Opus, fresh) | T-0012 | PASS (`b686b51`) |
| 2026-11-23 | Researchers ×4, Planners ×5, Plan Verifiers V1 to V3 (Opus) | T-0013 | Research, plan sections and audits done; fix pass running |
