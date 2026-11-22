# ADR-0003: Fleet operating model

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** Product Owner (model), Tech Lead (mechanics)
- **Related:** ADR-0002, T-0001, [fleet/protocol.md](../fleet/protocol.md), [fleet/roster.md](../fleet/roster.md)

## Context
The Product Owner wants a fleet: a Tech Lead that takes tasks from the PO and from crew members and orchestrates them across a team of agents. The Tech Lead acts on its own and asks the PO only about overall project direction. Parallel agents working in one repo risk merge conflicts, duplicated work and lost context.

## Decision
1. **Roles.** The PO owns direction. The Tech Lead (main Claude session) owns technical decisions, planning, dispatch, review and integration. Crew members are agents dispatched per task. See the [roster](../fleet/roster.md).
2. **Escalation boundary.** Only product direction goes to the PO: scope, priorities, UX intent, choices that cost money or involve third parties, and outward-facing actions such as pushing to a remote or publishing. Everything technical is decided by the Tech Lead and recorded as an ADR.
3. **One task, one crew member, one branch, one worktree.** Code-writing crew run in isolated git worktrees on `fleet/T-XXXX-<slug>`. Tasks run in parallel only when they don't touch the same files.
4. **Shared-file ownership.** Crew edit only their own task file and add new findings or ADR drafts. The Tech Lead alone edits `STATUS.md`, `tasks/BOARD.md`, `journal/`, `fleet/roster.md` and the index files, consolidating from handoff reports. This removes the most likely source of merge conflicts.
5. **Review before integration.** The Tech Lead reviews every branch (running `/code-review` where it is worth it), checks the [Definition of Done](../fleet/protocol.md#definition-of-done), then integrates. The integration policy, local merge versus PRs on a remote, is pending [Q-005](../open-questions.md#q-005).
6. **Crew may raise work.** Crew report follow-ups in the handoff report. The Tech Lead triages them into tasks, pending work or questions.

## Consequences
- **Positive:** parallel throughput without conflicts; a clear decision boundary; every unit of work is traceable from task to branch to review to docs.
- **Negative:** the Tech Lead is a bottleneck for shared docs and integration. That is acceptable at this team size; revisit if throughput suffers.
- **Follow-up:** once a remote exists, decide whether integration moves to PRs (T-0005 / Q-005).
