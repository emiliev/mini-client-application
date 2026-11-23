# T-0011: Full MVP journey e2e + visual sign-off

| Field | Value |
|---|---|
| Status | Superseded 2026-11-23: see [BOARD](BOARD.md#superseded-by-the-enterprise-plan-2026-11-23) |
| Owner | crew: Engineer; then crew: Verifier for visual sign-off |
| Branch | `fleet/T-0011-mvp-journey-e2e` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | F1 to F5 feature tasks, T-0010 |
| Related | ADR-0006, roadmap phase-2 exit |

## Goal
The final end-to-end proof that the MVP works as one product: a single journey through every feature on both reference iOS devices, with a screenshot tour the PO can review.

## Scope
- **In:** one e2e journey: launch → browse characters (scroll and paginate) → search → character detail → related comic → comic detail → favorite → favorites tab → relaunch shows the favorite persisted. Also an error-path journey (injected backend failure → error state → retry → content). Run on iPhone 17 Pro (iOS 26.2) and iPhone SE 3rd gen (iOS 18.2). Plus a screenshot tour, light and dark, in `documents/evidence/T-0011/`.
- **Out:** Android (follows Q-009).

## Acceptance criteria
_To be written as Given / When / Then once Q-008 confirms the feature set._

## Log
- 2026-11-22: Created from the PO request: "end up with an e2e test at the end, or build the app for iOS and visually test it."

## Superseded
2026-11-23: replaced by the enterprise plan. See [plan/README.md §6](../plan/README.md#6-superseded-and-rescoped-tasks).

## Outcome
_Pending._
