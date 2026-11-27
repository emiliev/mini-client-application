# T-0057: Pin the `AppFlows` async-guard paths (P-110)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier**. Test-only task: production code changes need TL approval, and any approved change makes this Opus tier (navigation, ADR-0011). |
| Branch | `fleet/T-0057-appflows-async-guard-pins` |
| Created | 2026-11-27 |
| Depends on | T-0054 |
| Related | T-0054 verification report D1 and D2, probes VP07b, VP16 and VP23, mutations X02, X03 and X06; F-0049; P-110 |

## Goal
The `/me/**` sign-in guard (next) will redirect asynchronously. Two `AppFlows` paths that only matter then are not tested yet: the supersede check and the first match by the push's completer. Pin them now, so the guard task can't break them silently.

## Scope
- **In:**
  - Add the T-0054 Verifier's probes VP07b (an async guard spanning frames), VP16 (an async guard plus a `go` in the same span) and VP23 (two calls in flight, the second redirected, then `router.replace` of the sign-in page). Put them in `app/wiring/app_core/test/flow_results_hardening_test.dart` as `T-0057-AC1 …` tests, adapted to the suite's helpers.
  - Show that mutations X02 (always superseded), X03 (never superseded) and X06 (match any pushed page) are each killed by the suite. Add them to `tool/checks/T-0054-AC5_mutations.sh`, or to a new `T-0057` script.
  - Record in F-0049 (TL-authorized):
    - a redirected page's pop value is lost after a re-parse (the call still ends once, with null);
    - after a guard's `go(from)` no caller waits for the editor's result.
- **Out:** production code. If a probe finds a real bug, stop and report to the TL. The guard itself and how home learns the result after `go(from)` are also out: the design decision goes to the guard task.

## Acceptance criteria
- **T-0057-AC1:** The three probes are committed tests, and they pass at HEAD.
- **T-0057-AC2:** X02, X03 and X06 are each killed by the suite (a mutation log with a control). A 50-run flake check of `flow_results_hardening_test` has 0 failures.
- **T-0057-AC3:** Gates: `test --lockfile_mode=error //...`, lint, format and `mc_arch_check` pass. `git diff origin/main --stat` shows only test, script and doc files.

## Log
- 2026-11-27: Created and dispatched (TL).
