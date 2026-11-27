# T-0054: `AppFlows` hardening: calls keyed per call, safe extras, results under overlays, a way home from not-found (P-094 to P-098)

| Field | Value |
|---|---|
| Status | In Review (engineer done; awaiting a fresh Verifier) |
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
- 2026-11-27: Engineer implemented AC1 to AC5 on `fleet/T-0054-flow-results-hardening`; merged `origin/main` (`ed3c2cd`, T-0053) and re-ran everything on the merged tree.

## Outcome

### AC to evidence
| AC | Evidence |
|---|---|
| T-0054-AC1 (P-094) | `app_core/test/flow_results_hardening_test.dart`, group `T-0054-AC1`: a result; Back; a `go` that replaces it; dispose; a guard redirect then `go(from)` (null once, no assert, the route a `go` built adds nothing); a redirect then Back; a redirect then go home; a redirected page that pops with a value (kills V08); two callers of one location; a forgotten `extra` still asserts and a `go` to the pushed location does not. Mutation V08 killed (log below) |
| T-0054-AC2 (P-095) | same file, group `T-0054-AC2`: JSON round-trip, FlowCall dropped, unsafe values (custom class, int keys, NaN, closures, a list holding one) dropped with one warning naming the type, self-reference, a custom extra pushed and reported (no throw, saved state has no trace, one codec warning, none from go_router, go_router's `logger` captured). T-0049 codec tests unchanged and green |
| T-0054-AC3 (P-096) | same file, group `T-0054-AC3`: complete then `go` before the dialog closes; dialog closes then `go`; both same-frame orders (dialog first, `go` first); an empty result; no result; a route removed from a plain Navigator while holding a result (no router). T-0048 / T-0049 overlay tests unchanged and green |
| T-0054-AC4 (P-097) | `mini_client/test/not_found_test.dart` (cold and running, for `/nope`, `/a/b/c`, `/comics/abc`: `[home, not-found]`, Back and Go home each reach home in one action; a not-found with nothing under it; one pushed over a page pops; URLs unchanged). e2e `not_found_cold_test`, `not_found_cold_bad_comic_test`, screenshots `60`..`62b` in `evidence/T-0054/engineer/e2e/` |
| T-0054-AC4 (P-098) | `deep_link_back_stack_test`: the `/characters/<id>` AC2 test now starts from home (name carries `T-0054-AC4`). Mutation P1 (links as a push) is killed by exactly that test |
| T-0054-AC5 | `tool/checks/T-0054-AC5_gates.sh` PASS ([gates.md](../evidence/T-0054/engineer/gates.md)): 167 tests, lint, arch, rules_fork, format, l10n, fixtures, relative paths, provenance, coverage mini_client 96.2 %, app_core 96.9 %. e2e: 13/13 PASS on own simulator `mc-T-0054-engineer-61021`, deleted. `tool/checks/T-0054-AC5_mutations.sh` |
| DoD flake rule | `--runs_per_test=50 --nocache_test_results` on every changed or added navigation target plus app_test, analytics_screens_test, router_observers_test, bdd_test: 8/8 pass, 0 failures ([log](../evidence/T-0054/engineer/runs_per_test_50.log)). None of the new tests drops a storage-writing future |

### Mutations
33 mutations (the Verifier's V08 and 32 of mine), **33 killed**, none broken, none survived ([log](../evidence/T-0054/engineer/mutations.log)). Two earlier candidates were dropped honestly: a "no first stack check after the push" mutant survived, because the listener makes that check redundant, so I removed the dead call; and the direct `_call?.complete(pending.value)` in `_deliver` is now an equivalent mutant (the call also holds the result), so it stays as an explicit guard and is not claimed as mutation-tested. P1 runs only the T-0054-AC4 test (`--test_filter`), because under a push the other deep-link tests wait out their timeouts.

### Plan 01 §4.4 sentence for the TL to apply (picker extras)
> A picker's arguments travel as the route's `$extra` and must be a JSON-safe value (null, bool, finite number, String, or a List or Map with String keys of those): `FlowExtraCodec` keeps only those when the route state is saved and drops anything else to null with a debug warning, so a picker reads a null `$extra` as "no argument" (it is also null after a restore) and never relies on a live object surviving.

### Decisions inside scope
1. **The page is found by its push future, not by extra or location.** A redirect drops the `extra`; the match keeps the completer whose future `routeInformationProvider.push` returned, so `AppFlows` calls that (what `GoRouter.push` does) and watches the delegate. The check runs after the next frame, because a page a `go` removed under a dialog is disposed late and must hand over its held result first.
2. **`FlowCall` holds the result** (`_hold` / `abandon`), so the stack watch and dispose both deliver a held result (P-096).
3. **The debug assert compares widget `extra` with `GoRouterState.extra`** and the location tokens are gone.
4. **Codec warning once per type** (a static set, with `resetFlowExtraWarnings()` for tests), because go_router encodes each imperative match on every report. Depth limit 32.
5. **Not-found is a route nested under home**, `/not-found?from=<path>` (named `not_found`), reached by `onException` (which sees both no-match and the typed route's redirect error for `/comics/abc`). `errorBuilder` is removed (go_router allows only one of them). `AppLocations` is unchanged; the new location lives in `app_router.dart`. The shown location is the link's path and query without `miniclient://app`.
6. `analytics_screens_test` (T-0053) lists every route name exactly; I added `not_found` to its expected set (one line).

### Changes outside `app_core` and `mini_client`
None in code. New scripts `tool/checks/T-0054-AC5_gates.sh` and `T-0054-AC5_mutations.sh`, and F-0049 (facts 7 to 9, rule, not done).

### Findings for the TL
- **`tool/e2e_ios.sh` can report a false PASS.** My first e2e run built two new targets with a compile error (`e2eStartLinkFile` is in `app_core`); the Xcode build failed, yet the target "passed" because an app installed by the previous target ran its own test and the script saw that pass. Look for `BUILD FAILED` in `e2e-*.log` (I do; none in the final run). Worth a pending-work item for the script (fail a target whose log has `BUILD FAILED` or `Failed to build`).
- Reproduced the Bazel `Checking Dart formatting` failure as a build error for an unformatted test file (a mutation script must run `dart format` after editing, which mine does).
