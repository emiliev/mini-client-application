# Glossary

| Term | Meaning |
|---|---|
| **mini-client** | The product we are building. Definition pending [Q-001](../open-questions.md#q-001). |
| **Fleet** | The team of AI agents working on this project: one Tech Lead plus crew members. See [ADR-0003](../adr/0003-fleet-operating-model.md). |
| **Product Owner (PO)** | Emil, the human who owns direction, scope and priorities. |
| **Tech Lead (TL)** | The main Claude session. It turns direction into tasks, makes technical decisions, dispatches and reviews crew, and integrates work. |
| **Crew member** | A Claude agent dispatched by the TL to do one task, usually in its own git worktree. |
| **Dispatch brief** | The instructions the TL gives a crew member ([protocol](../fleet/protocol.md#dispatch-brief)). |
| **Handoff report** | What a crew member returns when it finishes ([protocol](../fleet/protocol.md#handoff-report)). |
| **ADR** | Architecture Decision Record: a short document capturing one significant decision, its context and consequences. |
| **Finding** | A recorded piece of knowledge learned during work: a gotcha, root cause, spike result or benchmark. |
| **Pending work** | Known work that is not yet a scoped task: ideas, deferred items, tech debt. |
| **FVM** | Flutter Version Management. Pins the Flutter SDK per project. |
| **Worktree** | A git worktree: a separate checkout of the same repo, so parallel crew don't collide. |
