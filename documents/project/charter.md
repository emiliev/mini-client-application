# Project Charter — mini-client

> **2026-11-23: superseded in scope by the [enterprise plan](../plan/README.md).** The product is now a 169-module enterprise Marvel app in Tide's architecture, used to stress-test the Bazel rules (Q-006). The proposed MVP F1 to F5 are part of the catalogue. Sections below are kept for history.

- **Status:** Draft. Direction is confirmed (Q-001 to Q-005); the MVP feature set is proposed and awaits PO confirmation ([Q-008](../open-questions.md#q-008)). Finalised by [T-0002](../tasks/T-0002-product-charter.md).
- **Product Owner:** Emil
- **Tech Lead:** Claude (fleet lead session)
- **Last updated:** 2026-11-22

## Vision
A polished, mobile-first **Marvel universe app** for iOS and Android: browse and search characters and comics, dig into details, and keep favorites. It is built on a clean, swappable data layer and backed entirely by a mocked backend.

## Problem & target users
- **Users:** Marvel fans on phones who want a fast, pleasant way to explore characters and comics.
- **For the project itself:** a showcase of production-grade Flutter architecture, testing and delivery by an agent fleet, with every decision documented.

## Deliverable type
A **Flutter application** (not a package). Mobile-first, for **iOS and Android** (Q-001, Q-002).

## Identity
| Item | Value | Source |
|---|---|---|
| Bundle id / applicationId | `com.emiliev.miniclient` (TL choice; the PO delegated it, 2026-11-23) | Q-004 |
| Dart package name | `mini_client` | TL default |
| Display name | _TBD_, kept free of Marvel trademarks pending Q-007 | Q-007 |

## Data source
No real backend. A **`mocked_backend` module** inside the repo provides all data ([ADR-0005](../adr/0005-mocked-backend-module.md)). The app reaches it only through a data-source abstraction, so a real backend could replace it later without touching features.

## MVP features (proposed)
_Proposed by the TL; awaiting PO confirmation ([Q-008](../open-questions.md#q-008))._

| ID | Feature | Must-have behaviour |
|---|---|---|
| F1 | **Browse characters** | Paginated, infinitely scrolling list or grid with image and name |
| F2 | **Search characters** | Search by name, debounced, with empty and no-results states |
| F3 | **Character details** | Image, description, related comics (and series) |
| F4 | **Browse comics & comic details** | Paginated comics list; detail page with cover, description, creators, characters |
| F5 | **Favorites** | Favorite characters (and comics), saved locally, with a favorites tab |

Across all features: loading, empty and error states with retry (the mock can simulate latency and failures); light and dark theme; accessible text scaling.

## Goals (MVP)
1. F1 to F5 run on an iOS simulator against `mocked_backend`. Android is deferred by the PO ([Q-009](../open-questions.md#q-009)).
2. The architecture follows the PO's stack (Q-006), with every significant choice recorded as an ADR.
3. Quality gates (format, analyze, tests) are automated and green on `main` (T-0005).
4. The data layer can swap the mock for a real backend with no changes in feature code.

## Non-goals
- A real backend, networking to Marvel servers, or building any server.
- User accounts, authentication, payments, push notifications.
- Web or desktop targets; tablet-optimised layouts are nice-to-have, not MVP.
- A public store listing before IP clearance ([Q-007](../open-questions.md#q-007)).

## Success criteria
- Every MVP feature has a Done task with verification evidence.
- `fvm flutter analyze` is clean and the unit and widget test suites pass in CI.
- The app builds in release mode for iOS (Android deferred, Q-009).
- `documents/` is current: STATUS, BOARD, ADRs and architecture overview match the code.

## Constraints (known)
- Flutter / Dart, SDK managed with FVM ([F-0001](../findings/F-0001-environment-survey.md)).
- Repo on GitHub, private ([F-0002](../findings/F-0002-github-remote-access.md)); integration per [ADR-0004](../adr/0004-git-integration-workflow.md).
- Fully documented in `documents/` ([ADR-0002](../adr/0002-documentation-as-code.md)), delivered by an agent fleet ([ADR-0003](../adr/0003-fleet-operating-model.md)).
- No copyrighted Marvel artwork bundled by default ([R-005](../risks.md)).
- **iOS first:** Android stays a target (Q-002), but building and verifying it is deferred until the PO re-enables it (Q-009, P-014).

## Stakeholders
| Role | Who | Responsibility |
|---|---|---|
| Product Owner | Emil | Direction, scope, priorities, outward-facing actions |
| Tech Lead | Claude | Technical decisions, planning, orchestration, integration |
| Crew | Claude agents | Task execution ([roster](../fleet/roster.md)) |
