# T-0079: `mcgen wire` owns the hand-written groups (route specs) and routes FW/DB flows (P-128 a, e)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**, reusing the T-0074 engineer) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates. Navigation/auth routes are touched, but `--check` byte-equality and the existing route tests are the guard, so no Verifier. |
| Branch | `fleet/T-0079-mcgen-route-specs` |
| Created | 2026-11-28 |
| Depends on | T-0074 (`wire`, `buildgen`, ADR-0018), T-0075/T-0076 (FW and DB archetypes) |
| Related | P-128 (a) and (e); plan 02 §2.8; F-0074; F-0049 (`nestUnderHome`), F-0066 (guard), F-0048/F-0054 (`AppFlows` result routes) |

## Goal
Phase E batches mostly add features to **existing** groups (`universe`, `publishing`, `commerce`, …). Today those 7 wiring groups are hand-written, so `wire` can't extend them. This task closes that gap.

## Scope
- **In:**
  - **A `route:` spec section, with an ADR-0018 amendment.** It covers:
    - the route path and parameters;
    - nesting (under home, or under a parent such as `/characters/:id`);
    - typed `extra`;
    - the result route (`AppFlows`);
    - the protected prefix for the guard;
    - `AppLocations` naming.
  - **Route specs for every exemplar and hand-built module** in the 7 hand-written groups, so `wire --check` regenerates those groups' route libraries, `RouteTargets` and `AppLocations` entries byte for byte, or as close as possible.
    - Navigator implementations stay owned.
    - Any file that can't regenerate is documented with the reason.
    - Any normalisation of hand-written files must not change behaviour: the app tests, route tests and drift tests stay green unchanged.
  - **FW and DB flows get routed** (P-128(e)):
    - FW as `AppFlows` result routes;
    - DB as plain routes.

    The catalogue opens them.
- **Out:** spec synthesis, batches.

## Acceptance criteria
- **T-0079-AC1:**
  - `wire --check` covers the 7 groups' route libraries, `RouteTargets` and `AppLocations`.
  - Every covered file is byte-equal, and the uncovered list comes with reasons.
  - The route, app, guard and deep-link tests are green unchanged, or with declared normalisations only.
- **T-0079-AC2:** probe in a temp copy. Add one new list-detail spec to an **existing** group (e.g. `universe`) and one FW spec. Then gen → wire → buildgen, with no hand edits:
  - the sim build and `test //...` are green;
  - both flows open from the catalogue;
  - the FW flow returns its result to the caller.
- **T-0079-AC3:** gates:
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, the format gate, `T-0065-AC5_gates.sh`, `ci.sh --only 6`;
  - a 20-run flake check of the route and app tests;
  - unchanged lockfiles;
  - every cited test exists;
  - F-0074 and ADR-0018 updated.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the fourth wave.
