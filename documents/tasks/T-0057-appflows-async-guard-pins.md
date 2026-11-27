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
- 2026-11-27 (Engineer): Added VP07b, VP16 and VP23 (`replace` and `pushReplacement`) as 4 `T-0057-AC1` tests in `flow_results_hardening_test` (group `T-0057-AC1 the async-guard paths (P-110)`). The suite's `_App` gained an optional `guardDelay` (async guard on `/me/**`), a `/other` route and tagged `create`/`edit` helpers. All pass at HEAD, so no bug was found; no production change. Added `tool/checks/T-0057-AC2_mutations.sh` (refuses a dirty tree, trap before the first edit, BROKEN vs KILLED, a control that cuts the new group out of the test file). F-0049 notes 10 and 11 added. Flake check 50 runs, 0 failures. Gates pass.

## Outcome
All three ACs pass. Test, script and doc files only.

| AC | Evidence |
|---|---|
| T-0057-AC1 | 4 tests in `app/wiring/app_core/test/flow_results_hardening_test.dart`, group `T-0057-AC1 the async-guard paths (P-110)`: slow async guard (VP07b), async guard plus `go` in one span (VP16), `replace` and `pushReplacement` (VP23). Each checks the exact completions (once, expected value) and that no delegate listener is left. They pass at HEAD |
| T-0057-AC2 | [mutations.log](../evidence/T-0057/engineer/mutations.log) from `tool/checks/T-0057-AC2_mutations.sh`: X02, X03 and X06 each SURVIVE the control (the suite without the new group) and are each KILLED by a `T-0057-AC1` test (X02 by the slow guard, X03 by the same-span test, X06 by the `replace` test). Flake check: [runs_per_test_50.log](../evidence/T-0057/engineer/runs_per_test_50.log), 50 runs, 0 failures |
| T-0057-AC3 | [gates.txt](../evidence/T-0057/engineer/gates.txt): `test --lockfile_mode=error //...` 178 pass, lint, format and `mc_arch_check` OK. `git diff origin/main --stat` shows only the test, the script, F-0049, this task file and evidence |
