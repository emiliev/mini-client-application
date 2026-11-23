# Glossary

## Product & domain
| Term | Meaning |
|---|---|
| **mini-client** | The product: a mobile-first Marvel app for iOS and Android ([charter](charter.md)). |
| **mocked_backend** | The in-repo module that provides all of the app's data in place of a real backend ([ADR-0005](../adr/0005-mocked-backend-module.md)). |
| **Fixture data** | The static dataset (characters, comics, …) shipped inside `mocked_backend`. |
| **Data-source interface** | The abstraction the app uses to fetch data. `mocked_backend` implements it, and a real backend could later. |
| **Character** | A Marvel character (hero, villain, …): name, description, image, related comics and series. |
| **Comic** | A single comic issue: title, issue number, cover, description, creators, characters. |
| **Series** | A sequence of comics published under one title. |
| **Event** | A cross-title storyline that spans several series. |
| **Creator** | A person credited on a comic (writer, artist, …). |
| **Bundle id / applicationId** | The app's unique store identifier on iOS / Android (`com.emiliev.miniclient`, Q-004, decided by the TL). |

## Process
| Term | Meaning |
|---|---|
| **Fleet** | The team of AI agents working on this project: one Tech Lead plus crew members ([ADR-0003](../adr/0003-fleet-operating-model.md)). |
| **Product Owner (PO)** | Emil, the human who owns direction, scope and priorities. |
| **Tech Lead (TL)** | The main Claude session. It turns direction into tasks, makes technical decisions, dispatches and reviews crew, and integrates work. |
| **Crew member** | A Claude agent dispatched by the TL to do one task, usually in its own git worktree. |
| **Dispatch brief** | The instructions the TL gives a crew member ([protocol](../fleet/protocol.md#dispatch-brief-engineer)). |
| **Handoff report** | What a crew member returns when it finishes ([protocol](../fleet/protocol.md#handoff-report-engineer)). |
| **ADR** | Architecture Decision Record: a short document capturing one significant decision, its context and consequences. |
| **Finding** | A recorded piece of knowledge learned during work: a gotcha, root cause, spike result or benchmark. |
| **Pending work** | Known work that is not yet a scoped task: ideas, deferred items, tech debt. |
| **FVM** | Flutter Version Management. Pins the Flutter SDK per project. |
| **Worktree** | A git worktree: a separate checkout of the same repo, so parallel crew don't collide. |
