# T-0054: `AppFlows` hardening: calls keyed per call, safe extras, results under overlays, a way home from not-found (P-094 to P-098)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Opus tier** (app navigation; ADR-0011) |
| Branch | `fleet/T-0054-flow-results-hardening` |
| Created | 2026-11-27 |
| Depends on | T-0049 (`FlowCall`, `FlowExtraCodec`, `nestUnderHome`) |
| Related | T-0049 verification report D1–D5; F-0048, F-0049; plan 01 §4.2–§4.4 (guards with `from=`, picker extras) |

## Goal
Make the T-0049 flow-result machinery safe before two things land:
- **The `/me/**` sign-in guard.** It redirects and then replaces with `go`, and P-094 hangs that caller.
- **The first picker that passes an extra.** Under P-095 it would crash.

The not-found screen also needs a way home.

## Scope
- **In:**
  - **P-094.** Key the hand-over token by the `FlowCall` itself, not by location.
    - Chain the `push` future into the call, so a call ends in exactly one of three ways: a result, a null on dispose, or a null when go_router completes the push.
    - A redirect (to sign-in), then a `go` to the original location (`from=`), must complete the original caller exactly once. It must not fire the "built without its FlowCall" debug assert on a correct route.
    - The assert must still fire on a route that really forgets `extra: state.extra`.
  - **P-095.** `FlowExtraCodec` encodes `FlowCall` (dropped on save, as now) and JSON-safe values (null, bool, num, String, List/Map of those).
    - Any other extra is dropped on save (decoded as null), with a debug-only warning naming its type. It must never throw on the iOS route report.
    - Document the rule for picker arguments in plan 01 §4.4 via the task's Outcome. The TL applies the plan edit.
  - **P-096.** A result held under an overlay is delivered, not replaced by null, when a `go` disposes the route before the overlay closes.
  - **P-097.** The not-found page is reachable at any path, cold or running. It gets a back button that goes home when there is nothing under it, and a "Go home" action. Unknown paths and bad ids (`/comics/abc`) behave the same.
  - **P-098.** Make the T-0049 AC2 `/characters/<id>` test start from home, so it tells a `go` from a `push`.
- **Out:** the auth guard itself (a later task), picker features.

## Acceptance criteria
- **T-0054-AC1 (P-094).**
  - Model the guard with a test-only `redirect`: push `AppFlows.x` while signed out, sign in, then `go(from)`. The original caller completes exactly once, with the right value (null or the result per the scenario), and no assert fires.
  - A route without `extra: state.extra` still trips the assert.
  - The T-0049 Verifier's mutation V08 (stop chaining the push future into the call) is now killed.
- **T-0054-AC2 (P-095).**
  - A non-JSON extra (a custom class), pushed and reported, does not throw. It decodes as null and logs one debug warning.
  - JSON-safe extras round-trip.
  - A `FlowCall` never appears in the saved state.
  - Capture go_router's log and the codec warning in a widget test.
- **T-0054-AC3 (P-096).** Show a dialog over a result route, complete the result, then `go` elsewhere before the dialog closes. The caller gets the result, exactly once. The existing T-0048 and T-0049 overlay tests stay green.
- **T-0054-AC4 (P-097, P-098).**
  - Cold `/nope` and `/comics/abc`: a back button, and "Go home". Each reaches home in one action. Check on your own simulator with screenshots.
  - Running app: a link to `/nope` gives `[home, not-found]`.
  - The rewritten P-098 test goes red when links are turned into a push.
  - `AppLocations` and the URLs are unchanged.
- **T-0054-AC5 (gates).**
  - Coverage ≥ 90 % for `app_core` and `mini_client`.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and the provenance check pass.
  - The full mini_client e2e passes on your own simulator. Delete it afterwards.
  - Deliver `tool/checks/T-0054-AC5_gates.sh` and a mutation script that refuses a dirty tree and tells a broken build from a killed mutation.
  - Update F-0049 with the new rules.

## Log
- 2026-11-27: Created and dispatched (TL).
